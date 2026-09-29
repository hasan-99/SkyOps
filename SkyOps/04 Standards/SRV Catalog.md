---
type: standard
tags:
  - standard
  - skyops
  - srv
author: Hasan Jahouse
version: 1
---

# SRV Catalog

Source of truth: `C:\SharedProjects\SkyOps\standards\SRV-CATALOG.md` — **never** `~/.claude/standards`, which `sky-review.md` explicitly calls out as a stale, incomplete duplicate copy.

Code format: `SRV-{LETTER}-{NNN}`. Letter = severity, number = a stable global counter that survives reclassification.

## Severity letters

- **C** — Critical, blocks merge
- **H** — High, blocks unless agreed
- **M** — Medium, fix-or-follow-up
- **L** — Low, optional
- **O** — CodePreferenceOptional, author can decline

## Categories (picked by root cause, not surface symptom)

Async/Concurrency · Performance · Security · SOLID · DDD · Naming · Error handling · Code Clarity · Data/Persistence · Globalization · Caching

## The 16 codes

| Code      | Category          | Title                                                                                                           |
| --------- | ----------------- | --------------------------------------------------------------------------------------------------------------- |
| SRV-H-001 | Async/Concurrency | Sync I/O inside an async method — see [[Async Change Guard Pattern]], [[sky-async-guard]]                       |
| SRV-L-010 | Async/Concurrency | CancellationToken accepted but not threaded through awaited calls (CA2016) — see [[Async Change Guard Pattern]] |
| SRV-H-006 | Globalization     | Culture/timezone-dependent DateTime or numeric parsing/formatting — see [[sky-i18n-guard]]                      |
| SRV-L-004 | Code Clarity      | Fat controller — logic belongs in the handler/service, not the controller — see [[sky-api]], [[sky-review-api]] |
| SRV-M-003 | Data/Persistence  | Unit-of-Work boundary misaligned with the transaction boundary — see [[sky-data]], [[sky-review-data]]          |
| SRV-H-014 | Data/Persistence  | Mutate-then-`SaveChanges` on an untracked entity under NoTracking default — silent data loss                    |
| SRV-H-016 | Data/Persistence  | Schema change reaches only some of the DBs a shared entity maps to                                              |
| SRV-M-012 | Performance       | Whole-table load instead of a pushed-down predicate — see [[sky-performance]], [[sky-review-performance]]       |
| SRV-M-013 | Performance       | Missing paging on a query that should page                                                                      |
| SRV-M-007 | Caching           | Cache write + TTL set non-atomically                                                                            |
| SRV-M-009 | Error handling    | Blind, unconditional rollback                                                                                   |
| SRV-L-002 | SOLID             | (see standards/SRV-L-002.md for full text)                                                                      |
| SRV-L-005 | Naming            | (see standards/SRV-L-005.md for full text)                                                                      |
| SRV-L-008 | Code Clarity      | (see standards/SRV-L-008.md for full text)                                                                      |
| SRV-L-015 | SOLID             | (see standards/SRV-L-015.md for full text)                                                                      |
| SRV-O-011 | Naming            | (see standards/SRV-O-011.md for full text)                                                                      |

Also see **`GROUNDING.md`** in `standards/` — the shared evidence law: cite `file:line` or drop the finding, no hedging, `INSUFFICIENT EVIDENCE` blocks an approve, deterministic severity→score rubric. Applied by [[sky-evidence]] and [[review-standards]] during [[Review Pipeline]] step 9.

## Who enforces what

- Write-time: [[sky-async-guard]] (H-001, L-010) · [[sky-i18n-guard]] (H-006) · [[sky-sql-destructive-guard]] (destructive SQL, not a numbered SRV — see its own note)
- Review-time, full sweep every time regardless of lane selection: [[sky-srv-standards]]
- Review-time, per-lane: [[sky-review-api]] (L-004 etc.) · [[sky-review-data]] (M-003, H-014, H-016) · [[sky-review-service]] (H-001, L-010) · [[sky-review-performance]] (M-012, M-013, M-007) · [[sky-review-security]]
- Shortlisting aid before the full sweep: [[sky-srv-select]]
- Post-hoc classification of findings already produced: [[review-standards]]

## See also

[[Repo Overview]] · [[Review Pipeline]]
