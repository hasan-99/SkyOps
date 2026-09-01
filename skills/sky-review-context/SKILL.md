---
name: sky-review-context
description: Resolves Jira requirement, acceptance criteria, comments, repositories, and review branches before code review begins.
user-invocable: false
---

# Sky Review Context

Gather review context before reading code.

## Jira

Read:

* key
* summary
* description
* acceptance criteria
* parent ticket when relevant
* all comments

Search comments for:

* `Branches for review`
* branch names
* repository names
* implementation notes
* reviewer notes
* developer notes
* scope clarifications

## Resolution Priority

When information conflicts, use:

1. explicit user instruction
2. latest explicit `Branches for review` comment
3. latest relevant Jira comment
4. ticket description

Explicit user branch or repository values override Jira-discovered values.

## Repository and Branch Resolution

For each involved repository:

1. Resolve repository path.
2. Fetch remote references.
3. Try the branch exactly as supplied.
4. If missing, search branches case-insensitively by Jira key.
5. Prefer the real matching branch including prefixes such as `MN/<KEY>`.
6. If branch was deleted after merge, allow commit fallback.
7. Never silently switch to an unrelated branch.

## Output

Return only compact structured context:

```yaml
jira:
  key:
  summary:
  requirement:
  acceptance_criteria:
  parent_context:
repos:
  - name:
    path:
    branch:
    source: user | jira_comment | commit_fallback
assumptions:
```

Keep only comments that materially affect scope or implementation understanding.
