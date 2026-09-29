---
type: command
tags: [command, skyops, test]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `commands/sky-test.md`
**Repo description:** Change-driven unit-test loop for CS_Datafactory_v2 (.NET 6). Takes the change on the current branch — from a bug fix, a resolved reviewer comment, or a /sky-task phase — maps it to the tests that cover it, edits existing tests or creates missing ones in the repo's exact xUnit + NSubstitute style, runs only the affected tests, fixes failures within a bounded budget, and commits on the branch. Chainable as the test step of /sky-task and the fix/comment flows.
**user-invocable:** true · **disable-model-invocation:** false
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# /sky-test

Change-driven unit-test loop, specifically for `CS_Datafactory_v2` (.NET 6). `disable-model-invocation: false`.

Args: `[scope] [commit=ask|auto|off] [max-fix=N] [run=affected|module|all]`.
- Default scope: `diff` vs `origin/dev`, normally sourced from a [[sky-scope]] manifest.
- Default `commit=ask` — honors the ask-before-push rule; `commit=auto` is an explicit per-run opt-in.
- **Never pushes, never posts to Jira.**

Nudged automatically after a C# source edit in `CS_Datafactory_v2` by the `edit-dispatch.js` hook — see [[Hooks]].

## Compare

[[sky-test-gap]] — reports what's untested *before* `sky-test` writes anything.

## See also

[[dotnet6-test-runner]] · [[sky-scope]]
