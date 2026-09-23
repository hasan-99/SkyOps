#!/usr/bin/env node
// SkyOps PreToolUse guard — dangerous git.
// Fires on Bash tool calls. Flags history-rewriting / work-destroying git
// operations and pushes to a protected branch, and asks for confirmation.
//
// Decision: "ask" — surfaces + confirms, never hard-blocks. --force-with-lease,
// pushing a feature branch, and normal git are left alone.
//
// Any error => allow (exit 0). The guard must never block work on its own bug.

//
// Runs standalone (stdin -> stdout JSON) and is also reusable: guard-dispatch.js
// requires `check(data)` so one Bash tool call spawns ONE node process instead
// of one per guard. The rules below are the single source of truth for both.

"use strict";

// Returns the ask-reason string, or null when the command is fine.
// Never throws: on any internal error the caller gets null (= allow).
function check(data) {
  try {
    const cmd = (data && data.tool_input && data.tool_input.command) || "";
    if (typeof cmd !== "string" || !/\bgit\b/.test(cmd)) return null;

    const reasons = [];

    // Force push (but not the safer --force-with-lease).
    if (/\bgit\s+push\b[^\n]*(--force\b(?!-with-lease)|\s-f\b)/i.test(cmd))
      reasons.push("force push overwrites remote history");

    // Push straight to a protected branch.
    if (/\bgit\s+push\b[^\n]*\b(main|master)\b/i.test(cmd))
      reasons.push("pushing directly to main/master (prefer a feature branch + review)");

    // Hard reset discards committed + working changes.
    if (/\bgit\s+reset\b[^\n]*--hard\b/i.test(cmd))
      reasons.push("git reset --hard discards uncommitted work");

    // Force clean removes untracked files/dirs.
    if (/\bgit\s+clean\b[^\n]*-[a-z]*f/i.test(cmd))
      reasons.push("git clean -f deletes untracked files");

    // Force-delete a branch.
    if (/\bgit\s+branch\b[^\n]*\s-D\b/.test(cmd))
      reasons.push("git branch -D force-deletes a branch (may lose unmerged commits)");

    // Discard working-tree changes via checkout/restore.
    if (/\bgit\s+checkout\b\s+(--\s+\.|\.)(\s|$)/.test(cmd))
      reasons.push("git checkout . discards local changes");
    if (/\bgit\s+restore\b(?![^\n]*--staged)[^\n]*(\.|\s--\s)/.test(cmd))
      reasons.push("git restore discards working-tree changes");

    // History rewriting.
    if (/\bgit\s+(filter-branch|filter-repo)\b/.test(cmd))
      reasons.push("history rewrite across the repo");
    if (/\bgit\s+push\b[^\n]*--delete\b/i.test(cmd))
      reasons.push("deleting a remote branch/ref");

    if (!reasons.length) return null;

    return (
      "SkyOps git guard — destructive/irreversible git op detected:\n  - " +
      reasons.join("\n  - ") +
      "\nIf this is intentional, confirm. Safer options: --force-with-lease instead of --force, " +
      "a feature branch instead of pushing to main, `git stash` instead of reset --hard."
    );
  } catch (e) {
    return null;
  }
}

module.exports = { check };

// Standalone mode — unchanged wire behaviour for anyone wiring this file directly.
if (require.main === module) {
  let input = "";
  process.stdin.on("data", (c) => (input += c));
  process.stdin.on("end", () => {
    let reason = null;
    try {
      reason = check(JSON.parse(input || "{}"));
    } catch (e) {
      reason = null;
    }
    if (!reason) process.exit(0);
    process.stdout.write(
      JSON.stringify({
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "ask",
          permissionDecisionReason: reason,
        },
      }),
      () => process.exit(0)
    );
  });
}
