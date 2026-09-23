#!/usr/bin/env node
// SkyOps PostToolUse dispatcher — Edit|Write|MultiEdit.
//
// One node process per edit instead of one per hook. Previously hooks.json
// wired dotnet-format.js and sky-test-nudge.js as two separate PostToolUse
// entries, so every Edit paid two node spawns. This reads stdin once and calls
// both in-process, in the original order: format first, then the test nudge.
//
// Matcher fidelity matters here — the two entries did NOT match the same set:
//   dotnet-format   Edit|Write|MultiEdit
//   sky-test-nudge  Edit|Write          <- no MultiEdit
// The consolidated entry matches the wider set, so the nudge is gated on
// tool_name below to keep it off MultiEdit exactly as before.
//
// Behaviour preserved: never blocks, never fails an edit, exit code always 0.
// The two hooks emit different fields (systemMessage vs additionalContext), so
// both survive in one payload with nothing dropped.

"use strict";

const dotnetFormat = require("./dotnet-format.js");
const testNudge = require("./sky-test-nudge.js");
const hookEnv = require("./hook-env.js");
const metrics = require("./metrics.js");
const elapsed = metrics.timer();

// Skip the nudge if the user already wired sky-test-nudge.sh for this event,
// so it does not fire twice. dotnet-format has no .sh port, so it always runs
// here. `SKYOPS_HOOK_IMPL=node` forces node to run everything.
const bashWired = hookEnv.wiredBashHooks("PostToolUse");

// sky-test-nudge was wired for Edit|Write only. Unknown/absent tool_name falls
// through to running it, matching the old behaviour when the field is missing.
function nudgeApplies(data) {
  const name = data && data.tool_name;
  return typeof name === "string" ? /^(Edit|Write)$/.test(name) : true;
}

// If no stdin arrives, don't hang the tool pipeline (inherited from the nudge).
const guard = setTimeout(() => finish(null, null), 1500);

let input = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (c) => (input += c));
process.stdin.on("end", () => {
  clearTimeout(guard);
  let message = null;
  let context = null;
  try {
    const data = JSON.parse(input || "{}");
    // tool_response is measured, never read or written: bytes only. duration_ms
    // is supplied by the harness (tool execution time, excluding hook time).
    metrics.record({
      kind: "tool",
      event: "PostToolUse",
      tool: typeof data.tool_name === "string" ? data.tool_name : "unknown",
      result_bytes: metrics.bytes(data.tool_response),
      input_bytes: metrics.bytes(data.tool_input),
      tool_ms: typeof data.duration_ms === "number" ? data.duration_ms : -1,
    });

    message = dotnetFormat.run(data);
    context =
      nudgeApplies(data) && !bashWired.has("sky-test-nudge.sh")
        ? testNudge.run(data)
        : null;
  } catch (e) {
    return process.exit(0); // never break the tool pipeline
  }
  finish(message, context);
});

function finish(message, context) {
  metrics.record({
    kind: "hook",
    hook: "edit-dispatch",
    event: "PostToolUse",
    ms: elapsed(),
    proc_ms: metrics.sinceProcessStart(),
    emitted_bytes: metrics.bytes(message) + metrics.bytes(context),
  });
  if (!message && !context) return process.exit(0);

  const out = { hookEventName: "PostToolUse" };
  if (message) out.systemMessage = message;
  if (context) out.additionalContext = context;

  // Write then exit via the flush callback — process.exit() before the pipe
  // drains would truncate the output.
  process.stdout.write(
    JSON.stringify({ hookSpecificOutput: out }),
    () => process.exit(0)
  );
}
