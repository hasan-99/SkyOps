---
name: sky-review-scope
description: Builds the exact Jira-ticket code scope from tagged commits, changed files, changed methods, tests, and minimal dependency context.
user-invocable: false
---

# Sky Review Scope

Use the Jira key as the primary change anchor.

## Commit Scope

For each repository:

1. Find ticket-tagged commits:
   `git log --grep=<KEY>`
2. Inspect commit metadata.
3. Build changed-file stats.
4. Build per-file diffs.
5. Identify changed methods, classes, contracts, queries, config, and tests.

Do not use whole branch-vs-master diff as the primary scope.

## Dependency Commit Exception

A non-tagged commit may be included only when concrete evidence shows it is required to:

* understand the ticket implementation
* build the ticket changes
* run affected tests
* validate changed behavior

Record why it was included.

Do not widen scope merely because adjacent commits exist.

## One-Hop Dependency Context

For changed production code, read only what is needed to understand the behavior:

* direct callers
* direct callees
* implemented interface
* request/response DTOs
* repository method
* affected entity/model
* relevant configuration
* directly related tests

Default to one hop.

Go deeper only when evidence requires it.

## Compact Flow Map

Build the smallest useful flow, for example:

`Controller -> Handler -> Repository -> Database -> Response`

or:

`Consumer -> Service -> External API -> Persistence`

## Output

```yaml
repos:
  - name:
    commits:
    dependency_commits:
    changed_files:
    changed_symbols:
    affected_tests:
    flow_map:
    extra_context:
```

Never load whole folders or projects for review.
