---
name: sky-review-flow
description: Performs the mandatory end-to-end integration review across all touched layers after specialist findings are collected.
user-invocable: false
---

# Sky Review Flow

Review the changed behavior as one composed flow.

Use:

* Jira requirement
* code-verifiable acceptance criteria
* compact flow map
* changed hunks
* minimal dependency context
* specialist findings

## Verify

1. Entry point passes correct values downstream.
2. Contracts match across layers.
3. IDs and keys keep the same meaning.
4. Nullability and optional values stay consistent.
5. Service calls the intended dependency.
6. Repository behavior matches service assumptions.
7. Data written and read matches the requirement.
8. Response maps from the correct source.
9. Error behavior propagates correctly.
10. Cancellation/async flow is coherent when relevant.
11. The composed implementation satisfies the acceptance criteria.

## Important

A component can be locally correct while the full flow is wrong.

Example:

`Controller sends CustomerId -> Service treats it as AccountId -> Repository query is locally valid`

This is a real integration defect even if each individual method looks reasonable.

## New Findings

Any new finding must use the same contract as specialist findings:

```yaml
severity:
category:
srv:
title:
file:
line:
problem:
why:
fix:
evidence:
confidence:
blocking:
```

No evidence means no finding.
