#!/usr/bin/env node
// SkyOps PostToolUse — .NET formatting nudge (and optional auto-format).
// Fires after Edit/Write/MultiEdit. Only acts on .cs files. NEVER blocks and
// NEVER fails the edit — worst case it exits 0 silently.
//
// Default (safe): emits a short reminder to format + build before committing.
// Opt-in: set env SKYOPS_AUTOFORMAT=1 and it actually runs
//   `dotnet format <nearest .csproj> --include <file>`
// scoped to just the changed file (best-effort, time-boxed).
//
// Rationale: auto-formatting every keystroke can churn files under the model,
// so real formatting is opt-in; the reminder is the zero-risk default.

"use strict";

const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

let input = "";
process.stdin.on("data", (c) => (input += c));
process.stdin.on("end", () => {
  try {
    const data = JSON.parse(input || "{}");
    const ti = data.tool_input || {};
    const file = ti.file_path || ti.path || "";
    if (typeof file !== "string" || !/\.cs$/i.test(file)) return done(); // not C#

    const auto = /^(1|true|yes|on)$/i.test(process.env.SKYOPS_AUTOFORMAT || "");
    const base = path.basename(file);

    if (!auto) {
      return message(
        `SkyOps: edited ${base}. Before committing, run \`dotnet format\` and a \`dotnet build\` on the affected project. (Set SKYOPS_AUTOFORMAT=1 to auto-format changed .cs files.)`
      );
    }

    const proj = nearestProject(file);
    if (!proj) return message(`SkyOps: edited ${base}; no .csproj found nearby to format.`);

    try {
      execSync(`dotnet format "${proj}" --include "${file}"`, {
        timeout: 55000,
        stdio: "pipe",
      });
      return message(`SkyOps: ran dotnet format on ${base}.`);
    } catch (e) {
      // dotnet missing, build errors, timeout — report, never block.
      return message(`SkyOps: dotnet format on ${base} did not complete (${short(e)}). Format manually before commit.`);
    }
  } catch (e) {
    return done();
  }
});

function nearestProject(file) {
  try {
    let dir = path.dirname(path.resolve(file));
    for (let i = 0; i < 12; i++) {
      const hit = fs.readdirSync(dir).find((f) => /\.csproj$/i.test(f));
      if (hit) return path.join(dir, hit);
      const parent = path.dirname(dir);
      if (parent === dir) break;
      dir = parent;
    }
  } catch (e) {}
  return null;
}

function short(e) {
  const m = (e && e.message) || String(e);
  return m.split("\n")[0].slice(0, 120);
}

function done() {
  process.exit(0);
}
function message(msg) {
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: { hookEventName: "PostToolUse", systemMessage: msg },
    })
  );
  process.exit(0);
}
