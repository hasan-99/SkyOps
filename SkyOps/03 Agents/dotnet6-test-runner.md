---
type: agent
tags: [agent, skyops, test]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `agents/dotnet6-test-runner.md`
**Repo description:** Authors and runs focused unit tests for changed .NET 6 code. Detects and follows the target repository's existing test conventions — framework, mocking library, assertion style, naming, SUT wiring — instead of imposing generic .NET defaults. Dispatched by /sky-task as the automated-test lane.
**model:** sonnet
**tools:** Read, Grep, Glob, Bash, Write, Edit
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# dotnet6-test-runner (agent)

Writes and runs xUnit + NSubstitute tests for recently changed .NET 6 code. Invoked proactively after significant code changes, new features, or bug fixes.

## See also

[[sky-test]] · [[sky-test-gap]] · [[sky-verification]]
