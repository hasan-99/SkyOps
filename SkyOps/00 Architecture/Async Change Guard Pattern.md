---
type: architecture
tags: [architecture, skyops, async]
author: Hasan Jahouse
version: 1.0
---

# Async Change Guard Pattern

The two-stage defense SkyOps runs for the same two SRV codes: catch it while typing, catch whatever slips past at review time.

## Stage 1 — write-time: [[sky-async-guard]]

Targets exactly:
- **SRV-H-001** — a method declared `async` calls a *synchronous* DB/HTTP/file API instead of the real `*Async` one (`.FirstOrDefault()` instead of `FirstOrDefaultAsync()`, `HttpClient.Send` instead of `SendAsync`, `File.ReadAllText` instead of `ReadAllTextAsync`). Also flags the disguised version: `Task.Run(() => syncCall())` moves the block to a thread-pool thread, it doesn't remove it.
- **SRV-L-010** — an async method takes no `CancellationToken` for cancelable work it awaits, or takes one and never threads it into the awaited calls (the CA2016 case) — cancellation becomes a no-op.

**Trigger:** a freshly declared `async` method or a freshly added/edited `await` chain, plus its direct call chain (private helpers/repo calls on that path only). It does not scan the whole file or repo, and won't flag pre-existing adjacent code.

**Behavior:** read-only by default — explains + shows the inline fix, does not edit files unless the user explicitly asks. Never runs builds/tests/formatters. Explicitly *not* a substitute for [[sky-review]] — it's the write-time catch; `sky-review` is the diff-wide catch.

## Stage 2 — review-time

- [[sky-service]] (agent form: [[sky-review-service]]) explicitly reviews "async + cancellation flow, SRV-H-001, SRV-L-010"
- [[sky-srv-standards]] always re-checks SRV-H-001/SRV-L-010 catalogue-wide regardless of what the lane gate selected
- The lane gate (`scripts/lane-gate.js`, see [[Review Pipeline]]) routes *every* `.cs` file change into the service lane automatically — its match pattern is literally `/\.cs$/i`

## The feedback loop

Confirmed findings that reach review get captured by [[sky-learn]] (`sky-review → confirmed findings → /sky-learn`). Per `sky-review.md` step 12, a lesson that keeps recurring (tracked via a `hits` counter in [[sky-learn]]) is what justifies promoting it into a dedicated write-time guard like `sky-async-guard` — closing the loop from review-time catch back to write-time guard.

## See also

[[SRV Catalog]] · [[Review Pipeline]] · [[sky-i18n-guard]] · [[sky-sql-destructive-guard]] (the other two write-time guards, same pattern, different SRV codes)
