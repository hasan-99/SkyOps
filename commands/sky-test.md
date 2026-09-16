---
name: sky-test
description: Change-driven unit-test loop for CS_Datafactory_v2 (.NET 6). Maps the change on the current branch to the tests that cover it, writes or edits tests in the repo's xUnit + NSubstitute style, and runs only the affected tests.
user-invocable: true
disable-model-invocation: true
---

# /sky-test

Run the **`sky-workflow-test`** skill now, with whatever the user passed to this command as its input.

That skill holds the complete workflow definition. This file is only the manual entry point — do not restate, summarise, or reimplement the workflow here.

**Manual invocation overrides automatic routing.** The user typed `/sky-test`, so run the test workflow directly rather than treating testing as a step inside a larger workflow.
