#!/usr/bin/env node
// SkyOps hook environment — the single source of truth for "which implementation
// should run", shared by the node dispatchers and by `scripts/hook-doctor.js`
// so the selection rule cannot drift between them.
//
// Why this exists: SkyOps ships hooks twice. The plugin manifest wires the
// portable `.js`; a Windows user may additionally wire the faster `.sh` ports in
// their own settings.json. Claude Code MERGES both, so the same guard then
// evaluates twice and an `ask` is confirmed twice. This module lets the node
// side notice a bash equivalent is already wired for the same event and stand
// down for that specific guard.
//
// Fail-safe direction: on ANY doubt — unreadable settings, bad JSON, unknown
// shape — report nothing wired, so the node implementation RUNS. A duplicated
// confirmation is a nuisance; a guard that silently stops guarding is not.

"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");

// Settings files Claude Code merges, in the order it reads them.
function settingsFiles() {
  const home = os.homedir();
  return [
    path.join(home, ".claude", "settings.json"),
    path.join(home, ".claude", "settings.local.json"),
  ];
}

// The .sh basenames wired for `event` in the user's settings. Empty set when
// nothing is wired, unreadable, or the override forces node.
function wiredBashHooks(event) {
  const found = new Set();
  // Escape hatch: SKYOPS_HOOK_IMPL=node forces the node path to do everything.
  if (/^node$/i.test(process.env.SKYOPS_HOOK_IMPL || "")) return found;
  for (const file of settingsFiles()) {
    try {
      if (!fs.existsSync(file)) continue;
      const cfg = JSON.parse(fs.readFileSync(file, "utf8"));
      for (const entry of (cfg.hooks && cfg.hooks[event]) || []) {
        for (const h of entry.hooks || []) {
          const m = String(h.command || "").match(/([\w.-]+\.sh)/);
          if (m) found.add(m[1]);
        }
      }
    } catch (e) {
      // Unreadable or malformed — treat as "nothing wired" so node still runs.
    }
  }
  return found;
}

// Locate a usable Git Bash, or null. Used by the diagnostic and to explain the
// wiring in install.ps1 output — never to spawn one from inside a hook.
function findBash() {
  const candidates = [
    process.env.SKYOPS_BASH,
    "C:\\Program Files\\Git\\bin\\bash.exe",
    "C:\\Program Files\\Git\\usr\\bin\\bash.exe",
    "C:\\Program Files (x86)\\Git\\bin\\bash.exe",
  ].filter(Boolean);
  for (const c of candidates) {
    try {
      if (fs.existsSync(c)) return c;
    } catch (e) {}
  }
  return null;
}

module.exports = { wiredBashHooks, findBash, settingsFiles };
