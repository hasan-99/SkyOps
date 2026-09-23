#!/usr/bin/env node
// SkyOps SessionStart hook — reconnect to active work after a compaction.
//
// This hook deliberately WRITES NOTHING. SkyOps already persists the state a
// compacted session needs, in two places that are the source of truth:
//
//   plans/<KEY>.plan.md            phase (Meta Status), Requirement Status table
//   .skyops/scope/<x>.scope.md     key, branch, base, head_sha, repos, files
//
// What was missing is not the state — it is the reconnect. After a compaction
// nothing deterministically tells the session that state exists, so it relied on
// the model remembering to look. That is exactly the "prompt rule the model
// might forget" that hooks exist to replace.
//
// So this emits a short pointer to those files and nothing else. No new
// checkpoint, no duplication of the manifest, and no persisted state that could
// go stale and override the repo: branch and HEAD are read live at restore time,
// and the manifest's freshness is computed by comparing its recorded head_sha to
// the current HEAD right now.
//
// Silent unless there is genuinely active work. No plan file and no manifest =>
// no output, so ordinary conversations are unaffected.
//
// Any error => exit 0 with no output. A restore hint must never break a session.

"use strict";

const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

function git(args, cwd) {
  try {
    return execFileSync("git", args, { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
  } catch (e) {
    return null;
  }
}

function firstLineMatching(file, re) {
  try {
    for (const line of fs.readFileSync(file, "utf8").split(/\r?\n/)) {
      const m = line.match(re);
      if (m) return m[1].trim();
    }
  } catch (e) {}
  return null;
}

// Count requirements whose Status is not Verified, reading only the
// "## Requirement Status" table. Returns null when the table is absent or
// unreadable, so the caller can say "unknown" rather than invent a number.
function openRequirements(planPath) {
  let lines;
  try { lines = fs.readFileSync(planPath, "utf8").split(/\r?\n/); } catch (e) { return null; }
  const start = lines.findIndex((l) => /^##\s+Requirement Status\s*$/i.test(l));
  if (start === -1) return null;

  let open = 0, seen = 0;
  for (let i = start + 1; i < lines.length; i++) {
    const line = lines[i];
    if (/^##\s/.test(line)) break;            // next section
    if (!line.trim().startsWith("|")) continue;
    if (/^\s*\|[\s:|-]+\|\s*$/.test(line)) continue; // separator row

    const cells = line.split("|").slice(1, -1).map((c) => c.trim());
    if (cells.length < 4) continue;
    if (!/^R\d+$/i.test(cells[0])) continue;  // header or malformed row
    // Strip markdown emphasis/code ticks: `**Verified**`, `Verified (structural)`.
    const status = cells[3].replace(/[*`_]/g, "").trim();
    seen++;
    if (!/^verified\b/i.test(status)) open++;
  }
  return seen ? open : null;
}

function plansDir() {
  for (const d of [
    process.env.SKYOPS_PLANS_DIR,
    process.env.CLAUDE_PLUGIN_ROOT && path.join(process.env.CLAUDE_PLUGIN_ROOT, "plans"),
    path.resolve(__dirname, "..", "plans"),
  ]) {
    try { if (d && fs.existsSync(d)) return d; } catch (e) {}
  }
  return null;
}

function scopeManifest(repoRoot, key, branch) {
  const dir = process.env.SKYOPS_SCOPE_DIR || path.join(repoRoot, ".skyops", "scope");
  let files;
  try { files = fs.readdirSync(dir).filter((f) => f.endsWith(".scope.md")); } catch (e) { return null; }
  if (!files.length) return null;
  const slug = (branch || "").replace(/[^\w.-]+/g, "-");
  const hit =
    (key && files.find((f) => f.includes(key))) ||
    files.find((f) => slug && f.includes(slug)) ||
    null;
  return hit ? path.join(dir, hit) : null;
}

function main() {
  const cwd = process.cwd();
  const repoRoot = git(["rev-parse", "--show-toplevel"], cwd);
  if (!repoRoot) return; // not a git repo — nothing to restore

  const branch = git(["rev-parse", "--abbrev-ref", "HEAD"], cwd);
  const head = git(["rev-parse", "HEAD"], cwd);
  const keyMatch = (branch || "").match(/([A-Z][A-Z0-9]+-\d+)/);
  const key = keyMatch ? keyMatch[1] : null;

  const lines = [];
  let openCount = null;   // requirements not yet Verified (null = unknown)
  let scopeFresh = null;  // true = reused, false = stale, null = unknown

  // --- plan file: phase + what is still open ---------------------------------
  const pdir = plansDir();
  let planPath = null;
  if (pdir && key) {
    const p = path.join(pdir, `${key}.plan.md`);
    if (fs.existsSync(p)) planPath = p;
  }
  if (planPath) {
    const status = firstLineMatching(planPath, /^\s*-\s*\*\*Status:\*\*\s*(.+)$/);
    // Requirements not yet Verified = what is left to do. Parsed only inside the
    // "## Requirement Status" section (the spine table has a different shape),
    // by column position, tolerating `**Verified**` and `Verified (structural)`.
    const open = openRequirements(planPath);
    openCount = open;
    lines.push(`- plan: ${planPath}${status ? ` (Status: ${status})` : ""}`);
    lines.push(
      `- open requirements: ${
        open === null ? "unknown (no Requirement Status table)" :
        open > 0 ? `${open} not yet Verified` : "none — all Verified"
      }`
    );
  }

  // --- scope manifest: freshness judged against HEAD right now ---------------
  const scopePath = scopeManifest(repoRoot, key, branch);
  if (scopePath) {
    const sha = firstLineMatching(scopePath, /^head_sha:\s*(\S+)/);
    let freshness = "freshness unknown";
    if (sha && head) {
      scopeFresh = sha === head;
      freshness = scopeFresh
        ? "current"
        : `STALE (captured at ${sha.slice(0, 8)}, HEAD is ${head.slice(0, 8)}) — re-run /sky-scope before trusting it`;
    }
    lines.push(`- scope manifest: ${scopePath} — ${freshness}`);
  }

  // One compaction event, plus whether the scope manifest was reusable. This is
  // the context-pressure and manifest-reuse signal — counts and flags only.
  try {
    const metrics = require("./metrics.js");
    metrics.record({
      kind: "compaction",
      event: "SessionStart",
      source: "compact",
      had_plan: !!planPath,
      scope_manifest: scopePath ? (scopeFresh === true ? "reused" : scopeFresh === false ? "stale" : "unknown") : "absent",
      open_requirements: typeof openCount === "number" ? openCount : -1,
    });
  } catch (e) {}

  // Meaningful active work only. Nothing found => say nothing at all.
  if (!lines.length) return;

  const context = [
    "SkyOps active work (restored after compaction — pointers only, all state lives in these files):",
    `- ticket: ${key || "(none in branch name)"}`,
    `- repo: ${path.basename(repoRoot)}   branch: ${branch || "(unknown)"}   HEAD: ${head ? head.slice(0, 8) : "(unknown)"}`,
    ...lines,
    "Read the plan file before continuing the task; it is the source of truth for phase and remaining work.",
    "Re-verify branch, working tree, and test/build state in this session — do not trust anything above as current beyond the live git values.",
  ].join("\n");

  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: context },
    }),
    () => process.exit(0)
  );
}

try {
  main();
} catch (e) {
  process.exit(0); // never break a session on a restore hint
}
