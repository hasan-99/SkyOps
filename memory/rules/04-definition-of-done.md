---
id: definition-of-done
title: Definition of Done
status: stable
---

# Definition of Done

Before calling implementation work complete, check the items that apply and report honestly on each:

- every acceptance criterion within the agreed scope is addressed
- the relevant tests were executed (not just written)
- lint / build were executed where appropriate
- the **actual exit codes** were read, not inferred from a pipe
- the current working-tree state is known (what is changed, staged, committed)
- known limitations, skipped checks, and blocked criteria are stated explicitly

Unchecked items are stated as unchecked. Do not pad the report with checks that were not performed.

## Done is not published

Implementation completion is separate from publishing. These are **never** automatically part of "done" and stay governed by their own permission rules:

```
commit · push · Jira comment · PR creation · merge · release
```

Finishing the code does not authorise any of them.
