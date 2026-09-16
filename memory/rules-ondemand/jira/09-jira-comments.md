---
id: jira-comments
title: Jira comment style
status: stable
---

# Jira comment style

Structured markdown, never a wall of prose:

- `###` section headers (one per repo, plus `Review result` / `Point to confirm` where they apply)
- `*` bullet lists, inline `code` for field / method / branch names
- short paragraphs; list every relevant repo and branch the user expects
- no em dash, en dash, or arrow glyphs inside sentences — write "to". The ban is on those glyphs, **not** on markdown bullets and headers.

For work-done / fix comments: lead with `### <KEY>: Fixed` (or the verdict word) plus one plain sentence, then checklist sections (Acceptance criteria, Changes, Verification) with each completed step prefixed `✅`, then a final `### Note` section for out-of-scope items or points to confirm — only if there is something to note.

**Why:** the user rewrote a flat-prose review comment into this structure and said it was much clearer. It supersedes the earlier "flat plain prose, numbered points only" read.

## Do not mention merge or build state

Never say a repo is behind Dev, needs a Dev merge, or fails to build locally because of the un-merged state. The user handles merges; it is not review content for the reporter. Report only what the change does and its verification.

## Mentions caveat

`addCommentToJiraIssue` with `contentFormat: markdown` does **not** render a `<custom data-type="mention" ...>` tag — it posts the raw tag as literal visible text. Address the person in plain text ("Hi Mina, ..."). A real clickable mention requires `contentFormat: adf` with a proper mention node.

Posting any comment still requires explicit permission for that action.
