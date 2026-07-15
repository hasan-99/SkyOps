# Standard Review Violations (SRV)

A team catalogue of code-review issues we see often enough to be worth naming. Each entry gets a code (`SRV-{LETTER}-{NNN}`) where the letter encodes severity and the number is a stable global counter.

## What is an SRV?

An **SRV** ("Standard Review Violation") is a named, reusable code-review finding. Instead of re-explaining the same issue on every PR, we give it a code and keep the local SRV file as the readable standard. In a PR you cite it as:

> `SRV-H-001` — `getIncidents` is sync inside an `async` method. See `SRV-H-001.md`.

The `SRV-` prefix disambiguates the code from Jira tickets (`CLS-…`) and makes citations searchable across PRs. The letter (`H` here) tells the reader the severity at a glance.

## Code format

`SRV-{LETTER}-{NNN}` where:

| Position | Meaning |
| --- | --- |
| `SRV-` | Namespace — always `SRV-`. |
| `{LETTER}` | Severity letter (see table below). |
| `{NNN}` | Three-digit global counter, unique across the whole catalogue. The number is the *stable identity* — only the letter changes if a violation is reclassified. |

## Severity

| Level | Letter | When to use |
| --- | --- | --- |
| Critical | `C` | Security holes, data loss/corruption, production outages. Blocks the merge. |
| High | `H` | Correctness or performance issues that will hurt in production. Blocks merge unless agreed otherwise. |
| Medium | `M` | Bugs in cold paths, race conditions in uncommon scenarios, fragile contracts. Fix or open a follow-up. |
| Low | `L` | Code quality, naming, minor smells. Recommended but optional. |
| CodePreferenceOptional | `O` | Team-style preference. Author can decline. |

If a violation is reclassified, only the letter changes — the number stays. Old citations are still findable by the number alone.

## Categories

Every SRV belongs to exactly one category. Pick the one that best describes the *root* of the problem, not the symptom (e.g. SRV-H-001 is **Async/Concurrency** even though it surfaces as a performance issue).

| Category | Scope |
| --- | --- |
| Async/Concurrency | async/await misuse, thread-pool starvation, races, deadlocks |
| Performance | hot-path inefficiency, N+1 queries, unnecessary allocations |
| Security | injection, authn/authz gaps, secrets, unsafe deserialization |
| SOLID | violations of SRP/OCP/LSP/ISP/DIP |
| DDD | leaky aggregates, anaemic models, misplaced domain logic |
| Naming | misleading identifiers, ambiguous booleans |
| Error handling | swallowed exceptions, wrong exception types, missing validation |
| Code Clarity | DRY/redundancy, dead defensive code, signatures that lie about parameter independence |
| Data/Persistence | transaction/UoW boundaries, DbContext lifetime, cross-store consistency |
| Globalization | culture/locale/timezone-sensitive parsing, formatting, string compare, encoding; `DateTimeKind`/UTC |
| Caching | cache TTL/expiry, key lifecycle & leaks, eviction, serialization, stampedes (Redis/distributed caches) |

## Index

### Async/Concurrency

| Code | Title | Summary |
| --- | --- | --- |
| [SRV-H-001](SRV-H-001.md) | Sync I/O inside `async` methods | Method is declared `async` but calls sync DB/HTTP I/O, blocking a thread-pool thread. Causes thread-pool starvation under load. |
| [SRV-L-010](SRV-L-010.md) | CancellationToken missing or not threaded through | An async method either takes no `CancellationToken` for the cancelable work it awaits, or accepts one and passes it to nothing (CA2016) — so cancellation is a no-op. Accept a token and flow it through every awaited call. |

### Code Clarity

| Code | Title | Summary |
| --- | --- | --- |
| [SRV-L-002](SRV-L-002.md) | Helper re-checks an invariant the caller already enforces | Helper takes parameters whose relationship is already enforced by the caller, then re-applies the same rule defensively inside. Invariant lives in two places; drift fails silently. |
| [SRV-L-008](SRV-L-008.md) | Copy-paste siblings: near-duplicate members that differ by one operation | Two+ members are identical except for a single operation/constant/type. Fixes drift between copies; extract one parameterized helper and pass the varying piece in. |
| [SRV-O-011](SRV-O-011.md) | Private methods ordered below public members | A private helper is declared above the type's public API, so the implementation detail reads before the contract. Order members by descending accessibility (public first, private last); enforceable with StyleCop SA1202. |

### Data/Persistence

| Code | Title | Summary |
| --- | --- | --- |
| [SRV-M-003](SRV-M-003.md) | Unit-of-Work boundary doesn't match the transaction boundary | A UoW aggregates repositories backed by different DbContexts/databases, so its `SaveChanges` can't be atomic and cross-DB writes are treated as one transaction when they can't be. |

### SOLID

| Code | Title | Summary |
| --- | --- | --- |
| [SRV-L-004](SRV-L-004.md) | Fat controller: the action does more than translate HTTP | A controller action inlines business logic and/or response-streaming mechanics instead of just bind → dispatch → map. Move logic to the handler/service and transport to a custom `IActionResult`. |
| [SRV-L-005](SRV-L-005.md) | Single Responsibility: one unit, one reason to change | A class/method interleaves its core job with a separable secondary concern (cross-cutting instrumentation, formatting, transport, orchestration), so it has more than one reason to change. Extract the concern to a decorator / behavior / filter / service. |

### Globalization

| Code | Title | Summary |
| --- | --- | --- |
| [SRV-H-006](SRV-H-006.md) | Culture/timezone-dependent DateTime parsing & formatting | `DateTime.Parse/TryParse/ToString` (and `ToUniversalTime()` on `Unspecified` kind) without `CultureInfo.InvariantCulture` + `DateTimeStyles` make the result depend on the server's locale/timezone. Same input, different machine → wrong, silent timestamps. |

### Caching

| Code | Title | Summary |
| --- | --- | --- |
| [SRV-M-007](SRV-M-007.md) | Cache write and its TTL set non-atomically | The write and its `EXPIRE` are separate commands, so a crash/cancel/exception between them leaves the key with no TTL — it never expires, and orphaned keys grow the keyspace unbounded. Make write+TTL one atomic command. |

### Error handling

| Code | Title | Summary |
| --- | --- | --- |
| [SRV-M-009](SRV-M-009.md) | Blind rollback: compensating for steps that may not have run | A `try`/`catch` undoes every step unconditionally, including ones that threw or never ran — corrupting state on the failure path (e.g. decrementing a counter that was never incremented). Track what completed; undo only those, in reverse. |

Each violation lives in its own Markdown file in this folder.
