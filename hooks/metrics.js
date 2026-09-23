#!/usr/bin/env node
// SkyOps metrics — a deliberately tiny recorder, not a telemetry framework.
//
// OFF BY DEFAULT. Nothing is recorded unless SKYOPS_METRICS=1. When off,
// record() returns on its first line, so the cost in a live hook is a single
// env lookup.
//
// It adds NO new hook spawns. Every call site is a hook that already runs, so
// measuring costs one small appended line, not another ~7s node start.
//
// WHAT IS RECORDED: sizes, counts, durations, and identifiers that are already
// names (a tool name, a slash-command name, a hook name, a decision word).
//
// WHAT IS NEVER RECORDED: prompt text, source code, file contents, tool results,
// command strings, diffs, findings, or any part of a conversation. Callers pass
// byte counts they measured themselves; this module never receives the payload.
// `sanitize()` below enforces that — non-finite numbers and any string that is
// not a short known-safe identifier are dropped rather than written.
//
// Storage: ~/.claude/skyops-metrics/<YYYY-MM-DD>.jsonl (machine-local, never in
// a repo — same convention as the ~/.claude/skyops-knowledge lesson store), or
// $SKYOPS_METRICS_DIR. One JSON object per line.

"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");

function enabled() {
  return /^(1|true|yes|on)$/i.test(process.env.SKYOPS_METRICS || "");
}

function dir() {
  return process.env.SKYOPS_METRICS_DIR || path.join(os.homedir(), ".claude", "skyops-metrics");
}

// Identifiers we are willing to write: short, no whitespace, no path separators.
// Anything else is dropped, so a caller cannot accidentally leak content.
const SAFE_ID = /^[A-Za-z0-9_.:-]{1,64}$/;

function sanitize(fields) {
  const out = {};
  for (const [k, v] of Object.entries(fields || {})) {
    if (typeof v === "number") {
      if (Number.isFinite(v)) out[k] = Math.round(v);
    } else if (typeof v === "boolean") {
      out[k] = v;
    } else if (typeof v === "string") {
      if (SAFE_ID.test(v)) out[k] = v; // a name, never a payload
    }
    // everything else (objects, arrays, long strings) is dropped on purpose
  }
  return out;
}

// Append one measurement. Never throws, never blocks, never breaks a hook.
function record(fields) {
  if (!enabled()) return;
  try {
    const d = dir();
    fs.mkdirSync(d, { recursive: true });
    const day = new Date().toISOString().slice(0, 10);
    const line = JSON.stringify({ ts: new Date().toISOString(), ...sanitize(fields) });
    fs.appendFileSync(path.join(d, `${day}.jsonl`), line + "\n");
  } catch (e) {
    // Metrics must never affect the workflow they measure.
  }
}

// Byte size of a value without retaining or writing it.
function bytes(value) {
  try {
    if (value == null) return 0;
    const s = typeof value === "string" ? value : JSON.stringify(value);
    return Buffer.byteLength(s, "utf8");
  } catch (e) {
    return 0;
  }
}

// Start a duration timer. Returns a function giving elapsed milliseconds.
function timer() {
  const t0 = process.hrtime.bigint();
  return () => Number(process.hrtime.bigint() - t0) / 1e6;
}

// Milliseconds since the Node process itself started, i.e. interpreter startup
// and module loading on top of the hook's own work. This is the number that
// matters on a Defender-scanned box, where the spawn — not the logic — is the
// cost. It still excludes OS exec time before Node's clock starts, so treat it
// as a lower bound on true spawn cost.
function sinceProcessStart() {
  try { return require("perf_hooks").performance.now(); } catch (e) { return -1; }
}

module.exports = { record, bytes, timer, sinceProcessStart, enabled, dir };
