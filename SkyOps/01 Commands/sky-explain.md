---
type: command
tags: [command, skyops, docs]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `commands/sky-explain.md`
**Repo description:** Turns a Jira ticket (often written by another AI, dense and hard to follow) into a simple, visual, human-readable brief. Fetches the ticket and valid comments, searches the actual repo to ground every requirement in real files, handlers, endpoints, and flow, then writes a self-contained color-coded HTML page — plain-language TL;DR, requirement checklist, a color-coded workflow diagram, a codebase map, what "done" looks like, and open questions. Read-only, standalone; run before or after /sky-task to actually understand the scope.
**user-invocable:** true · **disable-model-invocation:** true
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# /sky-explain

Turns a dense or AI-written Jira ticket into a simple visual HTML brief. Output lands in `briefs/`. Pure read-only informational command — omits the [[sky-next]] closing block (per its exemption alongside [[sky-map]] and [[sky-recall]]).

## See also

[[sky-docs]] · [[Repo Overview]]
