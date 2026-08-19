#!/usr/bin/env node
// PostToolUse (Edit|Write) nudge: after a C# SOURCE edit in CS_Datafactory_v2,
// remind the model to close the test loop with /sky-test diff.
// Emits nothing for anything else, so it is silent outside that repo's source.

'use strict';

function readStdin() {
  return new Promise((resolve) => {
    let data = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (c) => (data += c));
    process.stdin.on('end', () => resolve(data));
    // If no stdin arrives, don't hang the tool pipeline.
    setTimeout(() => resolve(data), 1500);
  });
}

function qualifies(fp) {
  if (!fp) return false;
  const p = fp.replace(/\\/g, '/').toLowerCase();

  // Only this repo.
  if (!p.includes('/cs_datafactory_v2/')) return false;
  // Only C# source.
  if (!p.endsWith('.cs')) return false;

  // Skip the test tree itself (we're nudging about the source that changed).
  if (p.includes('/test/')) return false;
  if (p.includes('.tests/')) return false;

  // Skip generated / build / non-unit-tested artifacts.
  if (p.includes('/obj/') || p.includes('/bin/')) return false;
  if (p.includes('/migrations/')) return false;
  if (p.endsWith('.g.cs') || p.endsWith('.designer.cs')) return false;
  if (p.endsWith('/assemblyinfo.cs') || p.endsWith('assemblyattributes.cs')) return false;

  return true;
}

(async () => {
  try {
    const raw = await readStdin();
    if (!raw.trim()) return process.exit(0);

    const payload = JSON.parse(raw);
    const fp =
      (payload.tool_input && payload.tool_input.file_path) ||
      (payload.tool_response && payload.tool_response.filePath) ||
      '';

    if (!qualifies(fp)) return process.exit(0);

    const name = fp.replace(/\\/g, '/').split('/').pop();
    const context =
      `You just edited C# source in CS_Datafactory_v2 (${name}). ` +
      `Before treating this change as done, close the test loop with /sky-test diff: ` +
      `map the change to the tests that cover it, edit existing tests or create missing ones ` +
      `in the repo's xUnit + NSubstitute style (plain Assert, per-module CreateSut/InMemory-vs-mock convention), ` +
      `run only the affected tests, fix failures within budget, and commit per the run's commit mode ` +
      `(ask-first unless commit=auto). If this edit was itself a test file or has no runtime surface, ignore this.`;

    // Write then exit via the flush callback — process.exit() before the pipe
    // drains would truncate the output.
    process.stdout.write(
      JSON.stringify({
        hookSpecificOutput: {
          hookEventName: 'PostToolUse',
          additionalContext: context,
        },
      }),
      () => process.exit(0)
    );
  } catch (_e) {
    // Never break the tool pipeline on a nudge failure.
    process.exit(0);
  }
})();
