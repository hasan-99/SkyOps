---
name: sky-debug
description: Bug hunting for C#/.NET 6. Traces an error back to its root cause, checks impact via parallel specialists, proposes a fix, then waits for APPROVE PLAN before changing code.
user-invocable: true
disable-model-invocation: true
---

# /sky-debug

Run the **`sky-workflow-debug`** skill now, with whatever the user passed to this command as its input.

That skill holds the complete workflow definition. This file is only the manual entry point — do not restate, summarise, or reimplement the workflow here.

**Manual invocation overrides automatic routing.** The user typed `/sky-debug`, so investigate even if the cause looks obvious and `sky-dispatch` would have routed straight to an implementation workflow.
