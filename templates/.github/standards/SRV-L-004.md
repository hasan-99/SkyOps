# SRV-L-004 — Fat controller: the action does more than translate HTTP

| Field | Value |
| --- | --- |
| **Severity** | `[LOW]` |
| **Category** | SOLID |

## PR comment template

```
**SRV-L-004 — Fat controller.** The action does more than bind → dispatch → map; move business logic to the handler and response/transport into a custom `IActionResult`.
```

## Summary

A controller action's only job is to **translate between HTTP and the application layer**: bind and validate the request, dispatch it, and map the result onto a status / headers / body. A *fat* action does more — it inlines domain/business logic, or the mechanics of producing the response (assembling headers, taking over `Response.Body` to stream a file). Either way the action's real intent is buried, the mechanics can't be reused or unit-tested without hosting the full MVC pipeline, and the next endpoint copy-pastes the same plumbing. This is the controller-specific, named case of a Single-Responsibility break (**[SRV-L-005](SRV-L-005.md)**): the action's one job is HTTP translation; everything else belongs to a collaborator.

## Where it shows up

Two common shapes:

- **Business logic in the action** — validation rules, entity mutation, or persistence orchestration written directly in the controller instead of delegated to a handler/service. The action references domain types and `DbContext`, not just request/response DTOs.
- **Transport mechanics in the action** (the variant catalogued here) — export/download endpoints that take over `Response.Body`: manual `Content-Type` / `Content-Disposition` / `Cache-Control`, `StartAsync`, and a write loop, all inlined. Streaming genuinely needs `HttpResponse`, so it must stay at the HTTP boundary — but it does **not** have to sit inside the action.

## Bad

```csharp
[HttpGet("export"), Produces("text/csv")]
public async Task ExportIncidents(
 [FromQuery] GetIncidentsRequestDto dto, CancellationToken ct)
{
 var result = await _sender.Send(new GetIncidentsExportQuery(dto), ct);
 if (!result.Success) return GetObjectResult(result);

 // ── transport mechanics inlined in the action: this is the fat part ──
 var fileName = result.Data.FileName;
 Response.ContentType = "text/csv; charset=utf-8";
 Response.Headers["Content-Disposition"] = $"attachment; filename=\"{fileName}\"";
 Response.Headers["Cache-Control"] = "no-store";

 await Response.StartAsync(ct);
 await _csvWriter.WriteAsync(Response.Body, result.Data.Rows, ct);
 // (the real code also inlines a stopwatch + started/completed/cancelled/failed
 // logging quartet here — that cross-cutting facet is SRV-L-005.)

 return new EmptyResult();
}
```

## Good

```csharp
// Action: bind → dispatch → map. Reads in one screen; its intent is obvious.
[HttpGet("export"), Produces("text/csv")]
public async Task ExportIncidents(
 [FromQuery] GetIncidentsRequestDto dto, CancellationToken ct)
{
 var result = await _sender.Send(new GetIncidentsExportQuery(dto), ct);
 return result.Success
 ? new CsvExportResult(result.Data, _csvWriter) // transport lives in the result type
 : GetObjectResult(result);
}

// Reusable result type: HTTP-response mechanics stay at the boundary but out of the action,
// and become unit-testable without hosting a controller.
public sealed class CsvExportResult(IncidentsExport data, IIncidentCsvExportWriter writer) : IActionResult
{
 public async Task ExecuteResultAsync(ActionContext ctx)
 {
 var ct = ctx.HttpContext.RequestAborted;
 var response = ctx.HttpContext.Response;
 response.ContentType = "text/csv; charset=utf-8";
 response.Headers.ContentDisposition =
 new ContentDispositionHeaderValue("attachment") { FileNameStar = data.FileName }.ToString();
 response.Headers.CacheControl = "no-store";

 await response.StartAsync(ct);
 await writer.WriteAsync(response.Body, data.Rows, ct);
 }
}
```

The action now states intent in three lines. The streaming is owned by one reusable, independently testable component; the query handler keeps doing the one thing it already did right — producing the rows and filename — with no `HttpResponse` leaking into it. (The business-logic variant fixes the same way: the rule/mutation moves into the handler or a domain service, and the action just dispatches.)

## Why it matters

- **Intent is buried.** The action's real job is a few lines; reviewers have to read past stream plumbing (or business logic) to see what the endpoint does.
- **Not reusable, not testable.** Inlined transport/logic can only be exercised by hosting the controller through the MVC pipeline. A result type, handler, or service is a plain class you unit-test directly.
- **Duplication that drifts.** The next export endpoint copy-pastes the header + stream block; a change has to be made in N actions, and they fall out of sync.
- **HTTP leaks into the wrong layer.** Business logic in an action binds domain rules to `HttpContext`/`ActionResult`, so they can't be reused by a job, a message consumer, or another endpoint.

## Fix checklist

- Reduce the action to three responsibilities: bind/validate, dispatch, map result → HTTP. Aim for a body that reads in one screen.
- Move response/transport mechanics (headers, `StartAsync`, `Response.Body` writes) into a custom `IActionResult` / `IResult`.
- Move business logic into the handler/service; never reference domain types or `DbContext` directly in the action.
- Never pass `HttpResponse` into a handler — the handler produces data (rows + filename), the result type writes it.
- Route cross-cutting concerns (timing, logging) through a filter, not the action — see **[SRV-L-005](SRV-L-005.md)**.
