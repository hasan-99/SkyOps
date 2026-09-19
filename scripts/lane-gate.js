#!/usr/bin/env node
// SkyOps lane gate — decides which sky-review specialist lanes have a real
// surface, from the changed file list alone.
//
// This is NOT a new orchestration layer. sky-review step 4 already selected
// lanes; it just did it by judgement, which drifts. This makes the same
// decision deterministic, testable, and free (no model call, no repo read).
//
// Input: changed paths as args, or one per line on stdin, or --scope <manifest>
// Output: required lanes, and skipped lanes each with the reason.
//
// Safety rule, deliberately asymmetric: the gate may only skip a lane when NO
// rule matched. Ambiguity includes the lane. sky-review may always ADD a lane
// the gate skipped; it must never DROP one the gate required.
//
// Self-test: node scripts/lane-gate.js --selftest

"use strict";

const fs = require("fs");

// Each lane: the path patterns that give it a concrete surface, and the
// sentence explaining a skip. Ordered so the reason reads well in a report.
const LANES = [
  {
    key: "api",
    label: "API",
    match: [/controller/i, /\bendpoints?\b/i, /\broutes?\b/i, /request.*dto/i, /response.*dto/i, /\bcontracts?\//i],
    skip: "no controller, route, or request/response contract changed",
  },
  {
    key: "service",
    label: "Service",
    match: [/handler/i, /service/i, /manager/i, /\bcommands?\//i, /\bqueries\//i, /usecase/i, /\.cs$/i],
    skip: "no C# behaviour changed",
  },
  {
    key: "data",
    label: "Data",
    match: [/repositor/i, /\bentit(y|ies)\b/i, /dbcontext/i, /migration/i, /\.sql$/i, /\bmodels?\//i, /configuration.*entity/i, /\bdata\//i],
    skip: "no DB, query, entity, or migration changes",
  },
  {
    key: "security",
    label: "Security",
    // A changed controller counts: a new/altered endpoint is new attack surface
    // even when nothing in its path says "auth".
    match: [/auth/i, /permission/i, /\brole/i, /tenant/i, /validator/i, /token/i, /secret/i, /credential/i, /\bcors\b/i, /policy/i, /login/i, /identity/i, /claims?/i, /controller/i],
    skip: "no auth, tenant, permission, validation, or endpoint surface touched",
  },
  {
    key: "performance",
    label: "Performance",
    match: [/repositor/i, /\bquer(y|ies)\b/i, /cache/i, /batch/i, /\bjobs?\b/i, /worker/i, /bulk/i, /import/i, /export/i, /\bgrid\b/i, /paging/i, /\.sql$/i],
    skip: "no query, caching, batching, or bulk-data path changed",
  },
];

// Paths that are never a review surface for any lane.
const IGNORE = [/[\\/](obj|bin|node_modules|dist)[\\/]/i, /\.(md|txt|json|ya?ml|lock|png|svg|ico)$/i, /[\\/]migrations?[\\/].*designer\.cs$/i];

function gate(paths) {
  const files = paths.map((p) => String(p).trim()).filter(Boolean).filter((p) => !IGNORE.some((r) => r.test(p)));

  const required = [];
  const skipped = [];
  for (const lane of LANES) {
    const hit = files.find((f) => lane.match.some((r) => r.test(f)));
    if (hit) required.push({ ...lane, because: hit });
    else skipped.push(lane);
  }
  return { files, required, skipped };
}

function render({ files, required, skipped }) {
  const out = [];
  if (!files.length) {
    out.push("No reviewable files changed — no lanes required.");
    out.push("(sky-srv-standards still runs on every review.)");
    return out.join("\n");
  }
  out.push("**Required:**");
  for (const l of required) out.push(`- ${l.label} — ${l.because}`);
  if (!required.length) out.push("- (none)");
  if (skipped.length) {
    out.push("");
    out.push("**Skipped:**");
    for (const l of skipped) out.push(`- ${l.label} — ${l.skip}`);
  }
  out.push("");
  out.push("sky-srv-standards always runs and is not gated.");
  return out.join("\n");
}

// Pull the changed-file list out of a /sky-scope manifest without re-reading
// the repo — the whole point is to spend nothing here.
function fromScope(file) {
  const raw = fs.readFileSync(file, "utf8");
  const sec = raw.split(/^##\s+Changed files\s*$/im)[1];
  if (!sec) return [];
  return sec
    .split(/^##\s/m)[0]
    .split(/\r?\n/)
    .map((l) => l.match(/^-\s+([^\s(]+)/))
    .filter(Boolean)
    .map((m) => m[1]);
}

// ------------------------------------------------------------------ selftest
function selftest() {
  const cases = [
    {
      name: "controller only -> API+Service+Security, skip Data+Perf",
      files: ["src/Api/Controllers/AlertsController.cs"],
      require: ["api", "service", "security"],
      skip: ["data", "performance"],
    },
    {
      name: "repository -> Data+Service+Perf, skip API",
      files: ["src/Data/Repositories/AlertRepository.cs"],
      require: ["data", "service", "performance"],
      skip: ["api"],
    },
    {
      name: "plain handler -> Service only",
      files: ["src/Handlers/ChangeAlertStatusCommandHandler.cs"],
      require: ["service"],
      skip: ["api", "data", "security", "performance"],
    },
    {
      name: "validator -> Security (validation surface)",
      files: ["src/Validators/SocAlertsDtoValidator.cs"],
      require: ["security", "service"],
      skip: ["api", "data", "performance"],
    },
    {
      name: "migration + sql -> Data+Perf, skip API",
      files: ["src/Migrations/20260101_AddReason.cs", "scripts/backfill.sql"],
      require: ["data", "performance"],
      skip: ["api"],
    },
    {
      name: "docs only -> nothing required",
      files: ["README.md", "docs/notes.txt"],
      require: [],
      skip: ["api", "service", "data", "security", "performance"],
    },
    {
      name: "build output ignored",
      files: ["src/obj/Debug/Foo.cs"],
      require: [],
      skip: ["api", "service", "data", "security", "performance"],
    },
    {
      name: "frontend tsx -> no C# lane claims it",
      files: ["Frontend/src/components/CsCombobox.tsx"],
      require: [],
      skip: ["api", "service", "data", "security", "performance"],
    },
  ];

  let failed = 0;
  for (const c of cases) {
    const r = gate(c.files);
    const req = r.required.map((l) => l.key).sort();
    const skp = r.skipped.map((l) => l.key).sort();
    const missing = c.require.filter((k) => !req.includes(k));
    const wrong = c.skip.filter((k) => !skp.includes(k));
    if (missing.length || wrong.length) {
      failed++;
      console.log(`FAIL  ${c.name}`);
      if (missing.length) console.log(`        expected required: ${missing.join(", ")} | got: ${req.join(", ") || "(none)"}`);
      if (wrong.length) console.log(`        expected skipped:  ${wrong.join(", ")} | got: ${skp.join(", ") || "(none)"}`);
    } else {
      console.log(`ok    ${c.name}`);
    }
  }
  console.log(`\n${cases.length - failed}/${cases.length} passed.`);
  process.exit(failed ? 1 : 0);
}

// ---------------------------------------------------------------------- main
const argv = process.argv.slice(2);
if (argv.includes("--selftest")) selftest();

const scopeIdx = argv.indexOf("--scope");
let paths = [];
if (scopeIdx !== -1 && argv[scopeIdx + 1]) {
  paths = fromScope(argv[scopeIdx + 1]);
} else {
  paths = argv.filter((a) => !a.startsWith("--"));
  if (!paths.length && !process.stdin.isTTY) {
    paths = fs.readFileSync(0, "utf8").split(/\r?\n/);
  }
}
console.log(render(gate(paths)));
