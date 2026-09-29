---
type: command
tags: [command, skyops, meta]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `commands/sky-lint.md`
**Repo description:** Checks SkyOps itself for framework defects — broken or misnamed frontmatter, hooks that ship but are wired nowhere, installer gaps, hard-coded machine paths, stale docs and drifted counts, version mismatches between VERSION/package.json/CHANGELOG, and orphan files. Run it before shipping a SkyOps change, and after editing any command, hook, or standard. Read-only.
**user-invocable:** true · **disable-model-invocation:** false
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# /sky-lint

Reviews SkyOps *itself* — unwired hooks, bad frontmatter, installer gaps, hardcoded paths, drifted doc counts, version mismatches. Backed by `scripts/skyops-lint.js`. Run before shipping a change to the SkyOps framework — see the change policy in [[Repo Overview]].

## See also

[[sky-doctor]] · [[sky-health]] · [[Hooks]]
