#!/usr/bin/env node
// SkyOps hook doctor — shows which hook implementation is ACTUALLY active.
//
// SkyOps ships each guard twice: the portable `.js` (wired by the plugin
// manifest) and a faster `.sh` port (optionally wired by the user in
// settings.json). Claude Code merges both sources, so it is easy to end up
// running both and confirming the same guard twice. This prints, per event,
// what is wired from where, which implementation wins, and whether anything is
// duplicated.
//
// Read-only. Never edits settings.json or hooks.json.
//
//   node scripts/hook-doctor.js            report
//   node scripts/hook-doctor.js --parity   also diff each .js against its .sh
//   node scripts/hook-doctor.js --metrics  summarise recorded measurements

"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

// Works from the repo (scripts/ beside hooks/) and from the installer's flat
// ~/.claude/bin/ layout, where every script sits in one directory.
const HOOKS = [path.resolve(__dirname, "..", "hooks"), __dirname].find((d) => {
  try { return fs.existsSync(path.join(d, "hook-env.js")); } catch (e) { return false; }
}) || __dirname;
const hookEnv = require(path.join(HOOKS, "hook-env.js"));

function read(f) { return fs.readFileSync(f, "utf8"); }
function exists(f) { try { return fs.existsSync(f); } catch (e) { return false; } }

// --- what the plugin manifest wires -----------------------------------------
function pluginHooks() {
  const out = {};
  const f = path.join(HOOKS, "hooks.json");
  if (!exists(f)) return out;
  let cfg;
  try { cfg = JSON.parse(read(f)); } catch (e) { return out; }
  for (const [event, entries] of Object.entries(cfg)) {
    for (const entry of entries || []) {
      for (const h of entry.hooks || []) {
        const m = String(h.command || "").match(/hooks[\/\\]([\w.-]+)/);
        (out[event] = out[event] || []).push({
          script: m ? m[1] : String(h.command || ""),
          matcher: entry.matcher || "(all)",
        });
      }
    }
  }
  return out;
}

// --- what the user's settings wire ------------------------------------------
function settingsHooks() {
  const out = {};
  for (const file of hookEnv.settingsFiles()) {
    if (!exists(file)) continue;
    let cfg;
    try { cfg = JSON.parse(read(file)); } catch (e) {
      console.log(`  ! ${file} is not valid JSON — ignored`);
      continue;
    }
    for (const [event, entries] of Object.entries((cfg && cfg.hooks) || {})) {
      for (const entry of entries || []) {
        for (const h of entry.hooks || []) {
          const cmd = String(h.command || "");
          const m = cmd.match(/([\w.-]+\.(?:sh|js))/);
          (out[event] = out[event] || []).push({
            script: m ? m[1] : cmd.slice(0, 60),
            matcher: entry.matcher || "(all)",
            source: path.basename(file),
          });
        }
      }
    }
  }
  return out;
}

// A .js and its .sh port are the same guard under two implementations.
const base = (s) => s.replace(/\.(js|sh)$/, "");
// Which guards a dispatcher covers, so overlap is detected across the merge.
const COVERS = {
  "guard-dispatch": ["sql-guard", "git-guard"],
  "edit-dispatch": ["dotnet-format", "sky-test-nudge"],
};
const expand = (s) => COVERS[base(s)] || [base(s)];

// --- metrics summary ---------------------------------------------------------
// Reads the jsonl the hooks append (numbers + identifiers only) and rolls it up.
if (process.argv.includes("--metrics")) {
  const metrics = require(path.join(HOOKS, "metrics.js"));
  const dir = metrics.dir();
  let files = [];
  try { files = fs.readdirSync(dir).filter((f) => f.endsWith(".jsonl")).sort(); } catch (e) {}
  if (!files.length) {
    console.log(`No metrics in ${dir}.`);
    console.log("Enable with SKYOPS_METRICS=1 (off by default; no new hook spawns).");
    process.exit(0);
  }
  const rows = [];
  for (const f of files) {
    for (const line of read(path.join(dir, f)).split(/\r?\n/)) {
      if (!line.trim()) continue;
      try { rows.push(JSON.parse(line)); } catch (e) {}
    }
  }
  console.log(`SkyOps metrics — ${rows.length} samples from ${files.length} file(s) in ${dir}\n`);

  const pct = (arr, p) => {
    if (!arr.length) return 0;
    const s = [...arr].sort((a, b) => a - b);
    return s[Math.min(s.length - 1, Math.floor((p / 100) * s.length))];
  };
  const group = (rs, keyFn, valFn) => {
    const m = new Map();
    for (const r of rs) {
      const k = keyFn(r); if (k == null) continue;
      const v = valFn(r); if (typeof v !== "number" || v < 0) continue;
      (m.get(k) || m.set(k, []).get(k)).push(v);
    }
    return m;
  };
  const table = (title, m, unit) => {
    if (!m.size) return;
    console.log(title);
    const wide = Math.max(...[...m.keys()].map((k) => k.length), 12);
    for (const [k, v] of [...m].sort((a, b) => b[1].length - a[1].length)) {
      const total = v.reduce((a, b) => a + b, 0);
      console.log(
        `  ${k.padEnd(wide)}  n=${String(v.length).padStart(4)}  ` +
        `p50=${String(pct(v, 50)).padStart(7)}${unit}  max=${String(pct(v, 100)).padStart(7)}${unit}  ` +
        `total=${String(total).padStart(9)}${unit}`
      );
    }
    console.log("");
  };

  table("Hook logic time (our code only)",
    group(rows.filter((r) => r.kind === "hook"), (r) => r.hook, (r) => r.ms), "ms");
  table("Hook process time (incl. Node startup — the real cost)",
    group(rows.filter((r) => r.kind === "hook"), (r) => r.hook, (r) => r.proc_ms), "ms");
  table("Tool result size (what lands in context)",
    group(rows.filter((r) => r.kind === "tool"), (r) => r.tool, (r) => r.result_bytes), "B");
  table("Tool execution time (harness-reported)",
    group(rows.filter((r) => r.kind === "tool"), (r) => r.tool, (r) => r.tool_ms), "ms");
  table("Prompt size by command (grouping key)",
    group(rows.filter((r) => r.kind === "prompt"), (r) => r.command, (r) => r.prompt_bytes), "B");

  const comps = rows.filter((r) => r.kind === "compaction");
  if (comps.length) {
    const tally = {};
    for (const c of comps) tally[c.scope_manifest] = (tally[c.scope_manifest] || 0) + 1;
    console.log(`Compactions: ${comps.length}`);
    console.log(`  scope manifest at compaction: ${Object.entries(tally).map(([k, v]) => `${k}=${v}`).join("  ")}`);
    console.log(`  had a plan file: ${comps.filter((c) => c.had_plan).length}/${comps.length}\n`);
  }

  // No agent-size table: SubagentStart carries only agent_id/agent_type — the
  // harness never exposes a subagent's input, so it cannot be measured without
  // logging prompts, which this design forbids. See hooks/README.md.
  process.exit(0);
}

const bash = hookEnv.findBash();
console.log("SkyOps hook doctor\n");
console.log(`Git Bash : ${bash ? bash : "not found — node is the only option"}`);
console.log(`Override : SKYOPS_HOOK_IMPL=${process.env.SKYOPS_HOOK_IMPL || "(unset -> auto)"}\n`);

const plugin = pluginHooks();
const user = settingsHooks();
const events = [...new Set([...Object.keys(plugin), ...Object.keys(user)])].sort();

let duplicates = 0;
for (const event of events) {
  console.log(`${event}`);
  const p = plugin[event] || [];
  const u = user[event] || [];
  for (const h of p) console.log(`  plugin   ${h.matcher.padEnd(22)} ${h.script}`);
  for (const h of u) console.log(`  ${h.source.padEnd(8)} ${h.matcher.padEnd(22)} ${h.script}`);

  // Effective implementation per guard.
  const guards = new Set([...p, ...u].flatMap((h) => expand(h.script)));
  for (const g of [...guards].sort()) {
    const viaSh = u.some((h) => h.script === `${g}.sh`);
    const viaJs = p.some((h) => expand(h.script).includes(g)) ||
                  u.some((h) => h.script === `${g}.js`);
    const hasShPort = exists(path.join(HOOKS, `${g}.sh`));
    let active, note = "";
    if (viaSh && viaJs) {
      // A node entry point stands down only if it actually consults hook-env.js.
      // Verified from the source, so this cannot go stale as hooks are added.
      const standsDown = p.some((h) => {
        if (!expand(h.script).includes(g)) return false;
        const f = path.join(HOOKS, h.script);
        try { return exists(f) && /hook-env/.test(read(f)); } catch (e) { return false; }
      });
      if (standsDown && !/^node$/i.test(process.env.SKYOPS_HOOK_IMPL || "")) {
        active = "bash";
        note = "node dispatcher stands down";
      } else {
        active = "BOTH";
        note = "DUPLICATE — fires twice";
        duplicates++;
      }
    } else if (viaSh) { active = "bash"; }
    else if (viaJs) { active = "node"; note = hasShPort && bash ? "a .sh port exists and would be faster" : ""; }
    else { active = "not wired"; }
    console.log(`    -> ${g.padEnd(16)} ${active}${note ? "  (" + note + ")" : ""}`);
  }
  console.log("");
}

if (duplicates) {
  console.log(`${duplicates} guard(s) fire twice. Remove the duplicate entry from settings.json,`);
  console.log("or set SKYOPS_HOOK_IMPL=node to run only the node path.\n");
} else {
  console.log("No duplicate guard execution detected.\n");
}

// --- optional parity run -----------------------------------------------------
if (process.argv.includes("--parity")) {
  if (!bash) { console.log("Parity: skipped — no Git Bash found."); process.exit(0); }
  const cases = [
    ["sql-guard", JSON.stringify({ tool_input: { command: 'sqlcmd -Q "DROP TABLE T"' } })],
    ["sql-guard", JSON.stringify({ tool_input: { command: "ls -la" } })],
    ["git-guard", JSON.stringify({ tool_input: { command: "git push --force origin main" } })],
    ["git-guard", JSON.stringify({ tool_input: { command: "git status" } })],
  ];
  let bad = 0;
  for (const [name, payload] of cases) {
    const js = spawnSync(process.execPath, [path.join(HOOKS, `${name}.js`)], { input: payload, encoding: "utf8" });
    const sh = spawnSync(bash, [path.join(HOOKS, `${name}.sh`)], { input: payload, encoding: "utf8" });
    const same = js.status === sh.status && !!(js.stdout || "").trim() === !!(sh.stdout || "").trim();
    if (!same) bad++;
    console.log(`Parity ${same ? "OK  " : "FAIL"} ${name}: js(exit=${js.status}) sh(exit=${sh.status})`);
  }
  console.log(bad ? `\n${bad} parity mismatch(es).` : "\nParity: .js and .sh agree.");
  process.exit(bad ? 1 : 0);
}
