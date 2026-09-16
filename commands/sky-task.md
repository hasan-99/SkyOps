---
name: sky-task
description: Master planner and phased executor for substantial backend C#/.NET 6 work. Writes a durable per-Jira plan file, waits for APPROVE PLAN, then implements phase by phase with a verification gate after each phase.
user-invocable: true
disable-model-invocation: true
---

# /sky-task

Run the **`sky-workflow-task`** skill now, with whatever the user passed to this command as its input.

That skill holds the complete workflow definition. This file is only the manual entry point — do not restate, summarise, or reimplement the workflow here.

**Manual invocation overrides automatic routing.** The user typed `/sky-task`, so run the task workflow even if `sky-dispatch` would have chosen a different one. If the ticket looks genuinely wrong for this workflow, say so in one line and run it anyway.
