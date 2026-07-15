# SRV-M-009 — Blind rollback: compensating for steps that may not have run

| Field | Value |
| --- | --- |
| **Severity** | `[MED]` |
| **Category** | Error handling |

## PR comment template

```
**SRV-M-009 — Blind rollback.** This `catch` undoes every step unconditionally, including ones that threw or never ran — so an early failure runs compensation for work that never happened (e.g. a `Decrement` after a failed `Increment` drives the counter negative). Track which steps actually completed and undo only those, in reverse order.
```

## Summary

A `try`/`catch` hand-rolls compensation (rollback) for a multi-step operation, but the `catch` undoes **every** step unconditionally — regardless of how far execution actually got. A failure in step 1 then runs the undo for steps 1…N, even though steps 2…N never happened. The result is silent state corruption on the failure path: a counter decremented below where it started, an "unregister" of something never registered, a delete of a row never written. Compensation must reverse only the steps that **actually completed**, in reverse order.

## Where it shows up

Hand-rolled sagas — "do A, then B, then C; on failure undo them" — without a database transaction. The tell: a single `catch` that calls the inverse of each forward step with **no record of which steps ran**.

## How it corrupts

```
IncrementRefCountAsync ──✗ throws──► catch runs anyway
 └─► DecrementRefCountAsync ──► count = -1
 (decremented a counter that was never incremented)
```

## Bad

```csharp
try
{
 var refCount = await _refCountService.IncrementRefCountAsync(canonicalKey); // may throw HERE
 await _intervalTracker.RegisterAsync(canonicalKey, dashboardId, refreshInterval);
 // … more steps …
}
catch
{
 // Runs no matter how far we got — undoes steps that may never have executed:
 await _refCountService.DecrementRefCountAsync(canonicalKey); // if Increment threw → counter goes negative
 await _intervalTracker.UnregisterAsync(canonicalKey, dashboardId); // unregisters something never registered
 throw;
}
```

## Good

```csharp
bool incremented = false, registered = false;
try
{
 await _refCountService.IncrementRefCountAsync(canonicalKey); incremented = true;
 await _intervalTracker.RegisterAsync(canonicalKey, dashboardId, refreshInterval); registered = true;
 // … more steps …
}
catch
{
 // Undo only what actually succeeded, in reverse order:
 if (registered) await _intervalTracker.UnregisterAsync(canonicalKey, dashboardId);
 if (incremented) await _refCountService.DecrementRefCountAsync(canonicalKey);
 throw;
}
```

Each forward step records that it completed; the `catch` reverses exactly those, newest-first. Make the compensating actions idempotent where you can, and don't let a failing compensation throw away the original exception — wrap the rollback in its own `try`/`catch`, log it, and rethrow the original. When the steps live in one store, prefer a real transaction over hand-rolled compensation entirely.

## Why it matters

- **Corrupts state on the failure path.** Compensation for steps that never ran drives counters negative, "undoes" registrations that never existed, deletes rows never written — damage added exactly when the system is already degraded.
- **Silent.** The bogus undo *succeeds*, so nothing surfaces — the state just drifts.
- **Asymmetric blast radius.** The same "didn't track what ran" flaw also tends to *miss* steps performed later (resources created after the tracked ones aren't undone), leaving orphans alongside the over-undone state.

## Fix checklist

- Record which steps actually completed (success flags, or a nested `try`/step-scoped structure).
- In the `catch`, undo **only** completed steps, in **reverse** order.
- Make compensating actions idempotent where possible.
- Wrap the rollback so a compensation failure logs and **rethrows the original** exception, not itself.
- If the steps share one store, use a transaction instead of hand-rolled compensation.
