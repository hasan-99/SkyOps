# SRV-M-003 — Unit-of-Work boundary doesn't match the transaction boundary

| Field | Value |
| --- | --- |
| **Severity** | `[MED]` |
| **Category** | Data/Persistence |

## PR comment template

```
**SRV-M-003 — Unit-of-Work spans two databases.** A UoW over two DbContexts can't make `SaveChanges` atomic — commit the source-of-truth DB, then sync the other idempotently.
```

## Summary

A transaction can only cover **one database**. In EF Core, one `DbContext` = one database = one transaction that either fully saves or fully rolls back.

The problem: the Unit of Work here is grouped by **topic** (an Alert UoW, an Incident UoW) instead of by **database**. So one UoW ends up holding two repositories that talk to two *different* databases. When you call its `SaveChanges`, it really fires **two separate saves** — one per database — that look like a single operation but aren't. If the first succeeds and the second fails, the two databases now disagree and nothing rolls them back.

This breaks **ACID** — the guarantees a real transaction gives you (**A**tomicity: all-or-nothing; **C**onsistency: never left half-done; **I**solation: concurrent work doesn't interfere; **D**urability: once saved, it stays saved). Two databases cannot share one ACID transaction, so any code that treats a two-database write as atomic is relying on a guarantee that doesn't exist.

## Where it shows up

A `*UnitOfWork` class that exposes repositories over two contexts — e.g. one repo on a per-tenant `ProjectContext` and another on a central `OdManagementContext` — and handlers that call two `SaveChanges` (often with a retry wrapper around the second) as though the pair were transactional.

## Bad

```csharp
// UoW boundary drawn by domain — but the two repos live in DIFFERENT databases:
public class AlertUnitOfWork : IAlertUnitOfWork
{
 public IAlertRepository AlertRepository { get; } // -> ProjectContext (per-tenant DB)
 public ISocAlertRepository SocAlertRepository { get; } // -> OdManagementContext (SOC DB)

 // "One" SaveChanges that is really TWO independent commits, one per database:
 public async Task SaveChangesAsync(CancellationToken ct)
 {
 await _projectContext.SaveChangesAsync(ct); // commits DB A
 await _odManagementContext.SaveChangesAsync(ct); // commits DB B — separate connection, separate commit
 }
}

// Handler mutates rows in two databases and "saves" them as if it were one operation:
alert.SetStatus(newStatus); // tracked by ProjectContext (DB A)
socAlert.Status = newStatus; // tracked by OdManagementContext (DB B)

await _retryWrapper.ExecuteWithRetryAsync( // the retry wrapper is a tell: the author knows this can half-fail
 ct => _alertUnitOfWork.SaveChangesAsync(ct), ct);
// DB A commits first. If DB B then throws (or the process dies between the two commits),
// the alert is "Closed" in the tenant DB while the SOC mirror is still "Open" — and there is
// no rollback, because the two commits were never in the same transaction.
```

## Good

```csharp
// One UoW per DbContext — boundary == transaction == database:
public interface IProjectUnitOfWork // owns ProjectContext: Alert, Incident, .. + one SaveChanges/transaction
{
 IAlertRepository AlertRepository { get; }
 IIncidentRepository IncidentRepository { get; }
 Task SaveChangesAsync(CancellationToken ct);
}

public interface ISocUnitOfWork // owns OdManagementContext: SocAlert, SocIncident, ..
{
 ISocAlertRepository SocAlertRepository { get; }
 Task SaveChangesAsync(CancellationToken ct);
}

// 1) Source of truth (ProjectContext) — committed atomically in its own transaction:
alert.SetStatus(newStatus);
await _projectUnitOfWork.SaveChangesAsync(ct);

// 2) Secondary mirror (OdManagementContext) — separate, idempotent sync.
// Transient DB faults (deadlock, timeout, throttle) are retried by EF Core's own
// execution strategy, configured once on the context:
// o.UseSqlServer(conn, sql => sql.EnableRetryOnFailure());
// If the whole step still fails, record it for reconciliation — never roll back step 1.
var socAlert = await _socUnitOfWork.SocAlertRepository.GetByAlertIdAsync(alert.Id, ct);
if (socAlert is not null)
{
 socAlert.Status = newStatus; // idempotent: applying twice = same result
 await _socUnitOfWork.SaveChangesAsync(ct);
}
```

Same-database work (e.g. creating an incident and assigning its alerts — both on `ProjectContext`) belongs in **one** `IProjectUnitOfWork` transaction; don't load through one UoW and write through another.

> **Why not `RetryWrapper` here?** The shared `Odyssey.ClearSkies.RetryWrapper` only treats network/HTTP exceptions as transient — it does **not** retry `SqlException`/`DbUpdateException`, so wrapping a `SaveChanges` in it retries nothing. For transient *database* faults use EF Core's `EnableRetryOnFailure`; reserve `RetryWrapper` for outbound external/HTTP calls.

## The team standard (one way for everyone)

When an operation must change **two databases**, follow this — do not invent per-feature variants:

1. **One UoW per `DbContext`.** A UoW owns exactly one context and its `SaveChanges`/transaction. Never aggregate repositories from two databases behind one UoW.

2. **Commit the source-of-truth DB first, atomically.** For tenant data that's the per-tenant `ProjectContext`. After this returns, the authoritative state is durable.

3. **Sync the other DB as a separate, idempotent step.** "Idempotent" = re-running it yields the same result (a status assignment qualifies; an append/increment does not). Let **EF Core's `EnableRetryOnFailure`** handle transient DB faults — *not* the `RetryWrapper`, which only retries HTTP/network errors. If the step still fails after that, record it for reconciliation; the mirror catches up to the source of truth, you never roll the source of truth back.

4. **Escalate to an outbox event only when crash-durability is required** — i.e. losing the sync if the process dies *between* steps 2 and 3 is unacceptable. Then write an outbox row inside the step-2 transaction and dispatch it with retry. This is the exception, not the default.

**Forbidden**, even though both DBs sit on one SQL instance today:

```csharp
// ❌ Spanning two DbContexts in one transaction.
using var tx = new TransactionScope(TransactionScopeAsyncFlowOption.Enabled);
await _projectUnitOfWork.SaveChangesAsync(ct);
await _socUnitOfWork.SaveChangesAsync(ct);
tx.Complete();
```

It promotes to a distributed transaction (MSDTC) — unsupported on Azure SQL, environment-fragile, and it breaks the moment a tenant DB is moved to a different server. Co-location is a provisioning detail; never make correctness depend on it.

## Why it matters

- **No atomicity across databases.** `SaveChanges` on a multi-context UoW issues separate commits per `DbContext`. If the second fails after the first commits, the two databases diverge with no rollback.
- **Confusing `SaveChanges` ownership.** When several UoWs share one Scoped context, any of their `SaveChanges` flushes the same context — you can commit another feature's half-done work, and "which UoW saves what" is undefined.
- **Correct-by-accident.** Code that loads via UoW-A and writes via UoW-B only works because they happen to share a Scoped context. Flip the DI lifetime and it silently breaks — the correctness isn't expressed in the code.
- **Hidden distributed transaction.** Treating two DBs as one transaction is an implicit DTC requirement that Azure SQL / cross-server setups won't honor; it degrades to best-effort with no recovery story.

## Fix checklist

- Define one UoW per `DbContext`/database; it owns that context's `SaveChanges` and transaction and exposes only repositories backed by that context.
- Do each same-database operation through a single UoW transaction; never load via one UoW and persist via another.
- For cross-database effects, follow **The team standard** above: commit the source-of-truth DB atomically, then sync the secondary as an idempotent retried step.
- Never wrap two `DbContext` saves in one `TransactionScope`/transaction — even on the same SQL instance.
- Escalate to an outbox event only when crash-durability between the two steps is required.
