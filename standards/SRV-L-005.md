# SRV-L-005 — Single Responsibility: one unit, one reason to change

| Field | Value |
| --- | --- |
| **Severity** | `[LOW]` |
| **Category** | SOLID |

## PR comment template

```
**SRV-L-005 — Single Responsibility violation.** A unit interleaves its core job with a separable concern (logging, retry, formatting…); extract it to a decorator / behavior / filter.
```

## Summary

The Single Responsibility Principle says a unit — a class or a method — should have **one reason to change**. It's violated when a unit interleaves its core work with a *separable secondary concern*: cross-cutting instrumentation (timing, logging, retry, caching), formatting/serialization, transport, or orchestration of unrelated steps. The core logic gets buried, the secondary concern is copy-pasted across siblings and drifts, and the unit can't be tested or changed in isolation. The fix always has the same shape: lift the secondary concern into its own collaborator so each piece has a single reason to change.

## Where it shows up

A method whose few lines of real work are wrapped in machinery that has nothing to do with that work — a `Stopwatch` plus a started/completed/failed log quartet, a hand-rolled `try`/`catch` retry loop, a manual cache get-or-add, or CSV/JSON formatting jammed into a handler. The give-away: the same wrapper reappears nearly verbatim across sibling methods or handlers, varying only in the line or two of real work in the middle.

## Is it actually SRP — or just a long method?

Before citing this, name **two independent reasons the unit would change** (e.g. *"the logging format changes"* vs *"the export columns change"*). If you can point at a concern that is **separable and reusable** — something a decorator/filter/behavior could own — it's this violation. If you can't name a second, separable reason, it's probably just a long method, not an SRP break; don't cite L-005.

## Bad

```csharp
// The unit's real work is one line (the WriteAsync). Everything around it is a separable
// concern — timing + structured logging — inlined, and copy-pasted onto the next handler.
var stopwatch = Stopwatch.StartNew();
logger.send("Incidents export started", _logFactory.CreateStart(dto, fileName), Priority.Informative);
try
{
 var rowCount = await _csvWriter.WriteAsync(Response.Body, result.Data.Rows, ct); // ← the actual job
 stopwatch.Stop();
 logger.send("Incidents export completed",
 _logFactory.CreateCompleted(dto, fileName, rowCount, stopwatch.ElapsedMilliseconds, Response.HasStarted),
 Priority.Informative);
}
catch (OperationCanceledException ex)
{
 stopwatch.Stop();
 logger.send("Incidents export cancelled", ex,
 _logFactory.CreateStopped(dto, fileName, stopwatch.ElapsedMilliseconds, Response.HasStarted), Priority.Informative);
 throw;
}
catch (Exception ex) // two reasons to change: the logging shape, OR the export itself
{
 stopwatch.Stop();
 logger.send("Incidents export failed", ex,
 _logFactory.CreateStopped(dto, fileName, stopwatch.ElapsedMilliseconds, Response.HasStarted), Priority.Error);
 throw;
}
```

## Good

```csharp
// Lift the separable concern into a collaborator. For MediatR handlers (this codebase
// dispatches via _sender.Send), one pipeline behavior instruments EVERY request:
public sealed class TimingLoggingBehavior
(IAppLogger logger)
 : IPipelineBehavior

{
 public async Task
 Handle(
 TRequest request, RequestHandlerDelegate
 next, CancellationToken ct)
 {
 var sw = Stopwatch.StartNew();
 logger.send($"{typeof(TRequest).Name} started", priority: Priority.Informative);
 try
 {
 var response = await next();
 logger.send($"{typeof(TRequest).Name} completed in {sw.ElapsedMilliseconds}ms", priority: Priority.Informative);
 return response;
 }
 catch (OperationCanceledException) { logger.send($"{typeof(TRequest).Name} cancelled", priority: Priority.Informative); throw; }
 catch (Exception ex) { logger.send($"{typeof(TRequest).Name} failed", exception: ex, priority: Priority.Error); throw; }
 }
}
// Registered once; every handler is timed and logged with no per-method boilerplate.
```

Pick the seam by layer: **MediatR handlers** → `IPipelineBehavior`; **DI services** → a decorator (e.g. Scrutor `.Decorate()`); **HTTP endpoints** → an action/endpoint filter; **request-wide** → middleware; **a genuinely different job in the same class** → a separate class. The concern now lives in one tested place, the core unit drops back to just its real work, and each has exactly one reason to change.

## Why it matters

- **More than one reason to change.** Every edit to the unit risks the unrelated concern, and vice versa — the two are coupled for no reason.
- **Duplication that drifts.** The secondary concern is copy-pasted per unit; copies fall out of sync — one logs the cancelled case, the next forgets it, a third uses the wrong `Priority`.
- **Buries the real logic.** A one-line operation reads as a 40-line method; reviewers hunt for the work inside the machinery.
- **Untestable in isolation, defeats the mechanism built for it.** Decorators, pipeline behaviors, filters, and middleware exist to apply a concern uniformly and test it once. Inlining throws away both the uniformity and the single point of change.

## Fix checklist

- Name the separable secondary concern (timing? logging? retry? caching? formatting? an unrelated step?).
- Confirm it's a real second *reason to change*, not just length (see the guard above).
- Pick the seam: decorator (DI), `IPipelineBehavior` (MediatR), action/endpoint filter or middleware (HTTP), or a separate class.
- Implement once; register/apply it to the whole set (all handlers / the decorated interface / the route group).
- Delete the inlined copies; unit-test the extracted collaborator in isolation.
