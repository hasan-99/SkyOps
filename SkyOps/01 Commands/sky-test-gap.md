---
type: command
tags: [command, skyops, test]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `commands/sky-test-gap.md`
**Repo description:** Reports the test gap before writing any test — what behaviour actually changed, which existing tests already cover it, what is genuinely uncovered, and the minimum set of tests worth adding, ranked. Read-only; it never writes a test. Run it before /sky-test when you want to decide what is worth testing rather than generate coverage.
**user-invocable:** true · **disable-model-invocation:** false
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# /sky-test-gap

Reports what's untested and the minimum worth adding — run before [[sky-test]] writes anything, to scope the work first.

## See also

[[dotnet6-test-runner]]
