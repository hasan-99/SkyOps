#!/usr/bin/env node
// SkyOps self-lint — checks the framework before its problems reach users.
//
// Every check here exists because the drift it catches actually happened:
// a hook shipped but wired nowhere, two install paths disagreeing about which
// hooks exist, a README claiming a guard/SRV count that stopped being true,
// docs pointing at a generated file that had been renamed.
//
// Read-only. Never edits. Exit 0 = clean or warnings only, 1 = error(s) found.
// Usage: node scripts/skyops-lint.js [--quiet]

"use strict";

const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const P = (...a) => path.join(ROOT, ...a);
const findings = [];
const add = (level, check, msg, where) =>
  findings.push({ level, check, msg, where: where || "" });

const read = (f) => fs.readFileSync(f, "utf8");
const exists = (f) => fs.existsSync(f);
const listMd = (dir) =>
  exists(P(dir))
    ? fs.readdirSync(P(dir)).filter((f) => f.endsWith(".md"))
    : [];

function frontmatter(file) {
  const raw = read(file);
  const m = raw.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!m) return null;
  const out = {};
  for (const line of m[1].split(/\r?\n/)) {
    const kv = line.match(/^([A-Za-z_][\w-]*):\s*(.*)$/);
    if (kv) out[kv[1]] = kv[2].trim().replace(/^["']|["']$/g, "");
  }
  return out;
}

// 1. Command + agent frontmatter is present, and name matches the filename.
for (const dir of ["commands", "agents"]) {
  for (const f of listMd(dir)) {
    const full = P(dir, f);
    const fm = frontmatter(full);
    const rel = `${dir}/${f}`;
    if (!fm) {
      add("error", "frontmatter", "no YAML frontmatter block", rel);
      continue;
    }
    if (!fm.name) add("error", "frontmatter", "missing `name:`", rel);
    else if (fm.name !== path.basename(f, ".md"))
      add("error", "frontmatter", `name "${fm.name}" != filename`, rel);
    if (!fm.description)
      add("error", "frontmatter", "missing `description:` (used for routing)", rel);
    else if (fm.description.length < 40)
      add("warn", "frontmatter", "description too short to route on", rel);
  }
}

// 2. Skills: every skills/<name>/ has a SKILL.md whose name matches the dir.
if (exists(P("skills"))) {
  for (const d of fs.readdirSync(P("skills"))) {
    const sk = P("skills", d, "SKILL.md");
    if (!exists(sk)) {
      add("error", "skills", "directory has no SKILL.md", `skills/${d}`);
      continue;
    }
    const fm = frontmatter(sk);
    if (fm && fm.name && fm.name !== d)
      add("error", "skills", `name "${fm.name}" != directory "${d}"`, `skills/${d}/SKILL.md`);
  }
}

// 3. Hook wiring both ways: every hooks.json command points at a file that
//    exists, and every script in hooks/ is referenced by hooks.json.
const hooksJson = P("hooks", "hooks.json");
const referenced = new Set();
if (exists(hooksJson)) {
  let cfg = null;
  try {
    cfg = JSON.parse(read(hooksJson));
  } catch (e) {
    add("error", "hooks", `hooks.json is not valid JSON: ${e.message}`, "hooks/hooks.json");
  }
  if (cfg) {
    for (const [event, entries] of Object.entries(cfg)) {
      for (const entry of entries || []) {
        for (const h of entry.hooks || []) {
          const m = String(h.command || "").match(/hooks\/([\w.-]+)/);
          if (!m) continue;
          referenced.add(m[1]);
          if (!exists(P("hooks", m[1])))
            add("error", "hooks", `${event} points at missing hooks/${m[1]}`, "hooks/hooks.json");
        }
      }
    }
  }
}
if (exists(P("hooks"))) {
  for (const f of fs.readdirSync(P("hooks"))) {
    if (!/\.(js|sh)$/.test(f)) continue;
    const base = f.replace(/\.(js|sh)$/, "");
    const wired = [...referenced].some((r) => r.replace(/\.(js|sh)$/, "") === base);
    if (!wired)
      add(
        "warn",
        "hooks",
        "ships but is wired in no hooks.json event — it will never fire for plugin users",
        `hooks/${f}`
      );
  }
}

// 3b. A .js and .sh pair for the same hook must be behaviour-identical —
//     whichever one hooks.json wires is the one users actually get.
//
//     Compare the RULE SET, not the file size. Size was the first attempt and
//     it was wrong: every .sh here is ~2-3x its .js purely because it
//     hand-rolls JSON parsing that JSON.parse gives the .js for free. That
//     heuristic reported three guards as "weaker" when all three had identical
//     rules. A check that cannot actually determine parity stays silent rather
//     than guessing.
if (exists(P("hooks"))) {
  const pairs = new Set(
    fs.readdirSync(P("hooks"))
      .filter((f) => /\.(js|sh)$/.test(f))
      .map((f) => f.replace(/\.(js|sh)$/, ""))
  );
  for (const base of pairs) {
    const js = P("hooks", `${base}.js`);
    const sh = P("hooks", `${base}.sh`);
    if (!exists(js) || !exists(sh)) continue;
    const jsRaw = read(js);
    const shRaw = read(sh);
    // An intentional asymmetry (one side carries extra CLI surface) declares
    // itself, so the check stays trustworthy instead of routinely ignored.
    if (/skyops-lint:\s*parity-exempt/.test(jsRaw) || /skyops-lint:\s*parity-exempt/.test(shRaw))
      continue;

    // Match to the *matching* closing quote, not to any quote character: these
    // rule strings legitimately contain backticks (`dotnet ef database drop`),
    // and a naive character class truncates them into a phantom difference.
    const jsRules = rulesOf(jsRaw, /reasons\.push\(\s*(["'`])((?:\\.|(?!\1).)*)\1/g, 2);
    const shRules = rulesOf(shRaw, /reasons\+=\(\s*'([^']*)'/g, 1);
    // Not every hook exposes a rule list (a nudge has none). With nothing
    // comparable on either side there is no claim to make — say nothing.
    if (!jsRules.size || !shRules.size) continue;

    const onlyJs = [...jsRules].filter((r) => !shRules.has(r));
    const onlySh = [...shRules].filter((r) => !jsRules.has(r));
    if (onlyJs.length || onlySh.length) {
      const wired = referenced.has(`${base}.js`) ? ".js" : referenced.has(`${base}.sh`) ? ".sh" : "(neither)";
      const detail = [
        onlyJs.length ? `.js-only: ${onlyJs.join("; ")}` : "",
        onlySh.length ? `.sh-only: ${onlySh.join("; ")}` : "",
      ].filter(Boolean).join(" | ");
      add(
        "error",
        "parity",
        `${base} rule sets differ (hooks.json wires ${wired}) — ${detail}`,
        `hooks/${base}`
      );
    }
  }
}

function rulesOf(src, re, group) {
  const out = new Set();
  for (const m of src.matchAll(re)) {
    const v = (m[group] || "").trim();
    if (v) out.add(v);
  }
  return out;
}

// 4. Installer coverage: anything in hooks/ or scripts/ should be copied.
if (exists(P("install.ps1"))) {
  const inst = read(P("install.ps1"));
  for (const [dir, label] of [["hooks", "hooks"], ["scripts", "scripts"]]) {
    if (!exists(P(dir))) continue;
    if (!inst.includes(`'${dir}'`) && !inst.includes(`"${dir}"`) && !inst.includes(`/${dir}`))
      add("warn", "install", `install.ps1 never references ${dir}/ — is it installed?`, "install.ps1");
  }
  for (const ext of [".sh", ".js"]) {
    const has = exists(P("hooks")) &&
      fs.readdirSync(P("hooks")).some((f) => f.endsWith(ext));
    if (has && !inst.includes(ext))
      add("warn", "install", `hooks/ contains ${ext} files but install.ps1 never mentions ${ext}`, "install.ps1");
  }
}

// 4c. Every command declares its closing block, either by wiring `sky-next` or
//     by opting out with a reason. A command that silently ends without a next
//     step leaves the user to work out what the report means.
for (const f of listMd("commands")) {
  const raw = read(P("commands", f));
  if (!/sky-next/.test(raw))
    add("warn", "next", "declares no closing block — wire `sky-next` or add `<!-- sky-next: not-applicable — reason -->`", `commands/${f}`);
}

// 4d. Stale product name. SkyOps was renamed from CopilotOps (ADR 0002); a
//     shipped asset still saying the old name misroutes and confuses.
for (const dir of ["commands", "agents", "skills"]) {
  if (!exists(P(dir))) continue;
  const files = dir === "skills"
    ? fs.readdirSync(P(dir)).map((d) => P(dir, d, "SKILL.md")).filter(exists)
    : listMd(dir).map((f) => P(dir, f));
  for (const full of files)
    if (/CopilotOps/.test(read(full)))
      add("warn", "naming", "still says CopilotOps — the product is SkyOps (ADR 0002)",
        path.relative(ROOT, full).replace(/\\/g, "/"));
}

// 5. Versions agree across VERSION, package.json and the top CHANGELOG entry.
let version = null;
if (exists(P("VERSION"))) version = read(P("VERSION")).trim();
if (exists(P("package.json"))) {
  try {
    const pkg = JSON.parse(read(P("package.json")));
    if (version && pkg.version !== version)
      add("error", "version", `package.json ${pkg.version} != VERSION ${version}`, "package.json");
  } catch (e) {
    add("error", "version", "package.json is not valid JSON", "package.json");
  }
}
if (version && exists(P("CHANGELOG.md"))) {
  const top = read(P("CHANGELOG.md")).match(/^##\s*\[([^\]]+)\]/m);
  if (top && top[1] !== version)
    add("error", "version", `newest CHANGELOG entry [${top[1]}] != VERSION ${version}`, "CHANGELOG.md");
}

// 6. README command table matches commands/ on disk, both directions.
if (exists(P("README.md"))) {
  const readme = read(P("README.md"));
  // Check every shipped asset type, not just commands. Only checking commands
  // is how 7 agents, 5 skills and 2 scripts went undocumented while this
  // passed clean.
  const onDisk = listMd("commands").map((f) => path.basename(f, ".md"));
  const assets = [
    ["command", "commands", onDisk],
    ["skill", "skills", exists(P("skills")) ? fs.readdirSync(P("skills")) : []],
    ["agent", "agents", listMd("agents").map((f) => path.basename(f, ".md"))],
    ["script", "scripts", exists(P("scripts")) ? fs.readdirSync(P("scripts")) : []],
  ];
  for (const [kind, dir, names] of assets)
    for (const n of names)
      if (!readme.includes(n))
        add("warn", "docs", `${kind} exists but is undocumented in README`, `${dir}/${n}`);
  // Reverse direction: a README reference to something that no longer ships.
  // Must know about every asset type the forward check knows about, or
  // documenting an agent looks like a phantom reference.
  const known = new Set(assets.flatMap(([, , names]) => names).map((n) => n.replace(/\.(js|sh|md)$/, "")));
  for (const m of readme.matchAll(/`(sky-[\w-]+)`/g))
    if (!known.has(m[1]))
      add("warn", "docs", `README references \`${m[1]}\` which no longer exists as a command, skill, agent, or script`, "README.md");

  // A stated count that drifts is worse than no count.
  const srvFiles = exists(P("standards"))
    ? fs.readdirSync(P("standards")).filter((f) => /^SRV-[A-Z]-\d+\.md$/.test(f)).length
    : 0;
  for (const m of readme.matchAll(/catalog(?:ue)?'?s?\s+(\d+)\s+SRVs?/gi))
    if (srvFiles && Number(m[1]) !== srvFiles)
      add("error", "docs", `README says ${m[1]} SRVs, standards/ holds ${srvFiles}`, "README.md");
  for (const m of readme.matchAll(/\((\d+)\s+SRVs:/g))
    if (srvFiles && Number(m[1]) !== srvFiles)
      add("error", "docs", `README says ${m[1]} SRVs, standards/ holds ${srvFiles}`, "README.md");
}

// 7. No machine-specific absolute paths outside the places that must name them.
const PATH_RE = /[A-Z]:\\Users\\[A-Za-z0-9._-]+/g;
const ALLOW_USER_PATHS = new Set(["install.ps1"]);
const scanDirs = ["commands", "agents", "hooks", "scripts", "standards", "skills"];
for (const dir of scanDirs) {
  if (!exists(P(dir))) continue;
  const walk = (d) => {
    for (const e of fs.readdirSync(d, { withFileTypes: true })) {
      const full = path.join(d, e.name);
      if (e.isDirectory()) { walk(full); continue; }
      if (!/\.(md|js|sh|json|ps1)$/.test(e.name)) continue;
      const rel = path.relative(ROOT, full).replace(/\\/g, "/");
      if (ALLOW_USER_PATHS.has(rel)) continue;
      const hits = read(full).match(PATH_RE);
      if (hits)
        add("warn", "paths", `hard-coded user path ${hits[0]}\\... — breaks on another machine`, rel);
    }
  };
  walk(P(dir));
}

// 8. Referenced sibling files actually exist (catches renames like index.tsv).
const GEN_RE = /\b(index\.(?:tsv|rec|json)|INDEX\.md)\b/g;
const generated = new Set();
for (const f of ["hooks/knowledge-recall.js", "hooks/knowledge-recall.sh"]) {
  if (!exists(P(f))) continue;
  for (const m of read(P(f)).matchAll(GEN_RE)) generated.add(m[1]);
}
if (generated.size) {
  for (const dir of ["commands", "hooks", "."]) {
    const files = dir === "."
      ? ["README.md", "CHANGELOG.md"].filter((f) => exists(P(f))).map((f) => P(f))
      : listMd(dir).map((f) => P(dir, f));
    for (const full of files) {
      for (const m of read(full).matchAll(GEN_RE))
        if (!generated.has(m[1]))
          add("warn", "docs", `references generated file \`${m[1]}\` that the engine no longer writes`,
            path.relative(ROOT, full).replace(/\\/g, "/"));
    }
  }
}

// ------------------------------------------------------------------ report
const quiet = process.argv.includes("--quiet");
const errors = findings.filter((f) => f.level === "error");
const warns = findings.filter((f) => f.level === "warn");

if (!findings.length) {
  console.log("SkyOps lint: clean.");
  process.exit(0);
}
const order = { error: 0, warn: 1 };
for (const f of findings.sort((a, b) => order[a.level] - order[b.level])) {
  if (quiet && f.level === "warn") continue;
  const tag = f.level === "error" ? "ERROR" : "warn ";
  console.log(`${tag}  [${f.check}] ${f.where ? f.where + " — " : ""}${f.msg}`);
}
console.log(`\n${errors.length} error(s), ${warns.length} warning(s).`);
process.exit(errors.length ? 1 : 0);
