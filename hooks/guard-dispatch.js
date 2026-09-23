#!/usr/bin/env node
// SkyOps PreToolUse dispatcher — Bash.
//
// One node process per Bash tool call instead of one per guard. Previously
// hooks.json wired sql-guard.js and git-guard.js as two separate PreToolUse
// entries, so every Bash call paid two node spawns (~9.3s each on a
// Defender-scanned Windows box). This reads stdin once and calls both guards
// in-process, in the original order: SQL first, then git.
//
// Rules are NOT duplicated here — each guard still owns its own rule set and
// still runs standalone if wired directly.
//
// Behaviour preserved: decision is "ask", never a hard block; any error =>
// allow (exit 0); exit code is always 0.

"use strict";

const sqlGuard = require("./sql-guard.js");
const gitGuard = require("./git-guard.js");
const hookEnv = require("./hook-env.js");
const metrics = require("./metrics.js");
const elapsed = metrics.timer();

// If the user already wired the faster .sh port of a guard for this event,
// Claude Code will run it too — so skip that guard here rather than asking
// twice. Decided per guard, so a half-wired setup keeps full coverage.
// `SKYOPS_HOOK_IMPL=node` forces node to run everything.
const bashWired = hookEnv.wiredBashHooks("PreToolUse");

let input = "";
process.stdin.on("data", (c) => (input += c));
process.stdin.on("end", () => {
  let reasons = [];
  try {
    const data = JSON.parse(input || "{}");
    // Order matches the original hooks.json entry order.
    reasons = [
      bashWired.has("sql-guard.sh") ? null : sqlGuard.check(data),
      bashWired.has("git-guard.sh") ? null : gitGuard.check(data),
    ].filter(Boolean);
  } catch (e) {
    return process.exit(0); // never block on our own error
  }

  // Sizes and a decision word only — never the command being guarded.
  metrics.record({
    kind: "hook",
    hook: "guard-dispatch",
    event: "PreToolUse",
    tool: "Bash",
    ms: elapsed(),
    proc_ms: metrics.sinceProcessStart(),
    decision: reasons.length ? "ask" : "allow",
    findings: reasons.length,
    stood_down: bashWired.has("sql-guard.sh") && bashWired.has("git-guard.sh"),
  });

  if (!reasons.length) return process.exit(0);

  // Both guards asked -> one "ask" carrying both reason blocks. A single hook
  // process can emit a single decision, and "ask" + "ask" was already "ask".
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "ask",
        permissionDecisionReason: reasons.join("\n\n"),
      },
    }),
    () => process.exit(0)
  );
});
