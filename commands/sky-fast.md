---
name: sky-fast
description: Fast planner for small, localized C#/.NET changes. Inspects only the affected files, builds a compact plan with a flowchart, and waits for APPROVE PLAN before any code changes.
user-invocable: true
disable-model-invocation: true
---

# /sky-fast

Run the **`sky-workflow-fast`** skill now, with whatever the user passed to this command as its input.

That skill holds the complete workflow definition. This file is only the manual entry point — do not restate, summarise, or reimplement the workflow here.

**Manual invocation overrides automatic routing.** The user typed `/sky-fast`, so run the fast workflow even if `sky-dispatch` would have chosen a different one. The one exception is the workflow's own escalation rule: if the change turns out to exceed the fast-mode limits once you look, escalate to `sky-workflow-task` and say why.
