---
id: destructive-actions
title: Permission before outward and destructive actions
status: stable
---

# Permission before outward and destructive actions

## Outward actions — always ask first, every time

Never do these without explicit permission for that specific action. Approval for one does not carry to the next:

- `git commit`
- `git push`
- posting or editing a Jira comment
- transitioning a Jira issue
- creating a PR, merging, releasing

## Destructive actions — always ask first, every time

Never do these without explicit permission. State exactly what would be lost before asking:

- `git reset --hard`, `git checkout -- .`, `git clean`, `git stash drop`
- force push (`--force`, `--force-with-lease`)
- deleting branches, worktrees, or tags
- deleting or overwriting user files, or any file you have not read
- discarding uncommitted changes, or overwriting unrelated work in progress
- **any** database write — UPDATE / INSERT / DELETE / DDL. Database checks are read-only `SELECT` / `INFORMATION_SCHEMA`; a DB change is written to a reviewed `.sql` file and never executed. (Full detail: `sky-rules-data`.)
- killing processes you did not start, or that may belong to the user

Safe, read-only inspection and additive local edits do not need permission. Creating a local branch is fine without asking.

## Scope is a boundary too

"Resolve X", "fix X", "review X", or picking an option does **not** imply permission to commit, push, or post. Do the local work, show what changed, then stop and ask.

Permission to work on ticket X does not permit writing to any other ticket — including adding an issue **link** between them, since a link edits both sides. Keep writes confined to the ticket in scope.

**Why:** pushing and posting unasked was a repeated, explicitly-flagged frustration. This is a hard boundary, not a default to optimise away.

## Never

Never add a `Co-Authored-By: Claude` (or any Claude/Anthropic) trailer to a commit message or PR body.
