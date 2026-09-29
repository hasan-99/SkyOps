---
type: command
tags: [command, skyops, review]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `skills/sky-draft-comment/SKILL.md`
**Repo description:** Drafts a short, paste-ready Jira completion comment for a ticket, with a repo and branch table, acceptance criteria marked done, and real test results. TRIGGER on any request to draft, write, prepare or update a Jira comment for a ticket, including the bare phrases "draft comment", "draft a comment", "draft the comment", "comment for CLS-NNNNN", "jira comment", "write up the ticket", "close out the ticket", or a request to summarise finished work for Jira. Fires on the plain-English phrasing, not only the slash command. Verifies branch, commit and test state before asserting anything. Never posts.
**user-invocable:** true · **disable-model-invocation:** ?
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# /sky-draft-comment

Drafts a paste-ready Jira completion comment — repo/branch table, AC-done table, real test results. Triggers on plain-English phrasing too ("draft comment", "close out the ticket"). **Never posts.**

Also exists as a background skill with `user-invocable: true` (the only skill with that flag).

## Compare

[[sky-review-finalize]] drafts a review **verdict** comment; this drafts a **delivery/completion** comment. Different formats — don't merge them.

## See also

[[sky-review]] · [[sky-jira-verify]]
