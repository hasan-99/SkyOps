---
id: volatile-state
title: Verify volatile state before reporting it
status: stable
---

# Verify volatile state before reporting it

**Memory tells you where to look, not what is currently true.**

Re-check volatile state in the current session before reporting or acting on it. Never quote old ticket memory as proof of current state:

- current branch, working-tree status, whether changes are committed, whether they are pushed
- Jira status, assignee, and comments
- process and port ownership
- test, lint, and build results
- endpoint / API behaviour
- whether a fix already exists on Dev
- whether a previous implementation assumption still holds

A memory entry carrying `last_verified` or `review_after` is a pointer to re-verify, not a result. If re-checking is impractical, say the state is unverified rather than asserting it.
