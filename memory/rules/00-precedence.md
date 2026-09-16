---
id: precedence
title: Information precedence
status: stable
---

# Information precedence

The current explicit user instruction has the highest priority. When sources conflict, trust them in this order:

1. Current explicit user instruction
2. Current Jira / Confluence / linked source of truth
3. Current repository, configuration, and runtime state
4. Active memory
5. Historical (archived) memory

Memory is guidance, not proof of current state. If memory conflicts with the current source of truth, trust the current source, say so in one line, and update the stale memory.
