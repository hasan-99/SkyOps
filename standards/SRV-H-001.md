# SRV-H-001 — Sync I/O inside `async` methods

| Field | Value |
| --- | --- |
| **Severity** | `[HIGH]` |
| **Category** | Async/Concurrency |

## PR comment template

```
**SRV-H-001 — Sync I/O inside `async` methods.** Sync DB/HTTP call inside an `async` method blocks a thread-pool thread; under load this starves the pool.
```

## Summary

A method is declared `async` but performs its I/O (database, HTTP, file) through a **synchronous** call. The thread is blocked for the duration of the I/O even though the signature implies non-blocking behaviour. Under load this causes **thread-pool starvation**: latency spikes and apparent hangs at low CPU.

## Thread lifecycle — why the thread doesn't get released

```
BAD — sync DB call inside an async method
─────────────────────────────────────────────────────────────────
Time → 0ms DB roundtrip (~100ms) done
Thread A: [start]──────[ BLOCKED on socket recv() ]──────[finish]
 ▲ ▲
 taken from pool returned to pool

Pool during the wait: A is missing for the full 100ms.
 Concurrent requests must use other threads
 or queue if the pool is exhausted.

GOOD — async all the way
─────────────────────────────────────────────────────────────────
Time → 0ms await yields DB completes done
Thread A: [start]──→ (back in pool).
(no thread waiting) . DB I/O is handled by the OS via
 . IOCP (Windows) / epoll (Linux).
 . No managed thread is parked..
Thread B: ──→ [finish]
 ▲
 any free pool
 thread picks up
 the continuation

Pool during the wait: A returned at the await — pool is full.
 The same physical thread can drive many
 in-flight async I/Os concurrently.
```

**Why the sync thread can't be released.** The sync call sits inside a kernel syscall (e.g. `recv()` on the DB socket). The OS scheduler has the thread parked there waiting for bytes — the .NET runtime has no way to reclaim it mid-syscall. The thread *is* the wait.

**Why the async thread can be released.** The async call registers a completion handle with the OS's async I/O mechanism (IOCP / epoll / `io_uring`) and the `await` yields back to the runtime before any blocking happens. The runtime puts the thread back in the pool. When the OS delivers the completion, the runtime schedules the continuation on any available thread.

**Why `Task.Run(() => syncCall())` doesn't help.** It just moves the blocked thread from the request thread to a thread-pool thread. Still one thread parked for the whole DB roundtrip — same starvation, plus context-switch overhead.

## Where it shows up

Service or handler methods that wrap a repository call. The repository exposes only synchronous methods (`getIncidents`, `getUsers`, `Find`, …), so the service forwards those — but its own signature is `async Task` because *something else* in the method (e.g. `SaveChangesAsync`) is async.

## Bad

```csharp
public async Task UpdateIncidentComment(
 int incidentId,
 int commentId,
 Guid currentUserId,
 string text,
 CancellationToken cancellationToken = default)
{
 // Synchronous DB call inside an async method — the thread is blocked here.
 var incident = _incidentUnitOfWork.IncidentRepository
 .getIncidents(ids: new[] { incidentId })
 .FirstOrDefault();

 // ..

 await _incidentUnitOfWork.SaveChangesAsync(cancellationToken);
}
```

Common variant that **does not fix it**:

```csharp
// Anti-pattern: moves the blocking onto a TP thread instead of removing it.
var incident = await Task.Run(() =>
 _incidentUnitOfWork.IncidentRepository
 .getIncidents(ids: new[] { incidentId })
 .FirstOrDefault());
```

## Good

```csharp
public async Task UpdateIncidentComment(
 int incidentId,
 int commentId,
 Guid currentUserId,
 string text,
 CancellationToken cancellationToken = default)
{
 var incident = await _incidentUnitOfWork.IncidentRepository
 .GetIncidentByIdAsync(incidentId, cancellationToken);

 // ..

 await _incidentUnitOfWork.SaveChangesAsync(cancellationToken);
}
```

The repository exposes a real async method that bottoms out at EF Core's `FirstOrDefaultAsync` / `ToListAsync` (or ADO.NET's `*Async`) and threads the `CancellationToken` all the way down.

## Additional example — sync materialization hidden in a sync helper

Extracting the sync call into a `private bool` helper does **not** fix it: the helper still materializes the EF query on the calling thread, and it's invoked straight off an `async` path, so the awaited method blocks anyway.

### Bad

```csharp
public async Task ExecuteLogsAsync(AlertLogsRequestVM request, CancellationToken ct)
{
 // IsCustomAlert is sync — its EF query blocks the thread-pool thread driving this async method.
 if (IsRecent(request) && !IsCustomAlert(request.AlertId))
 return await _cache.RetrieveAlertLogs(request, ct) ?? Empty();
 // ..
}

private bool IsCustomAlert(int alertId)
{
 var alerts = _alertRepository.getAlerts(alertIds: new[] { alertId }); // deferred EF IQueryable
 var alert = alerts.FirstOrDefault(); // ← synchronous materialization
 return alert?.CorrelationRuleId ExecuteLogsAsync(AlertLogsRequestVM request, CancellationToken ct)
{
 if (IsRecent(request) && !await IsCustomAlertAsync(request.AlertId, ct))
 return await _cache.RetrieveAlertLogs(request, ct) ?? Empty();
 // ..
}

private async Task IsCustomAlertAsync(int alertId, CancellationToken ct)
{
 var alert = await _alertRepository.GetAlertByIdAsync(alertId, ct); // real async repo method
 return alert?.CorrelationRuleId < 0;
}
```

A sync helper is still sync I/O on the thread that awaits it. Make the helper `async`, bottom it out at an async repo method (`FirstOrDefaultAsync` / `GetByIdAsync`), and thread the `CancellationToken` through.

## Why it matters

- ASP.NET / Kestrel serves requests from a fixed-size thread pool. Each blocked thread is one fewer thread available for incoming requests.
- The thread pool grows by roughly one thread per 500 ms by default, so bursts overrun it before it can catch up.
- Symptom: P99 latency cliff, CPU low, DB low, app appears hung. Looks like a deadlock; it's actually exhausted threads.
- `async` with a sync body is the worst of both worlds: state-machine overhead **and** blocking.

## Fix checklist

- Add a real async overload at the repository layer.
- Bottom out at EF Core `*Async` / ADO.NET `ExecuteReaderAsync` / `HttpClient.SendAsync` — not `Task.Run` over the sync method.
- Thread the `CancellationToken` through every layer.
- Delete the sync method once all call sites have migrated (don't leave both).
