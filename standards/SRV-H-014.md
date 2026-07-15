# SRV-H-014 — Mutate-then-`SaveChanges` on an untracked entity under a NoTracking-default context

| Field | Value |
| --- | --- |
| **Severity** | `[HIGH]` |
| **Category** | Data/Persistence |

## PR comment template

```
**SRV-H-014 — Write persists nothing under NoTracking.** The context defaults to `QueryTrackingBehavior.NoTracking`, so the fetched entity isn't tracked; mutating it and calling `SaveChanges` writes 0 rows yet reports success. Add `.AsTracking()` to the write-path fetch.
```

## Summary

When a `DbContext`'s global default is `QueryTrackingBehavior.NoTracking`, entities returned by a query are **detached** — EF keeps no change-tracking snapshot. A write method that fetches an entity, mutates it, and calls `SaveChanges()` **without marking it modified** persists **nothing**: the tracker sees no `Modified` entries, emits no `UPDATE`/`DELETE`, returns `0` affected rows — but the method returns normally, so the caller reports success. A **silent no-op**.

CREATE paths escape this because `Ctx.Add(entity)` sets state to `Added` explicitly; only the fetch → mutate → save (UPDATE / soft-delete) path is exposed.

## Where it shows up

Repository write methods on a context that inherits a NoTracking default (e.g. a `BaseContext.OnConfiguring` that calls `UseQueryTrackingBehavior(NoTracking)`). The write method reuses the same read helper (`GetXxx(...)`) that queries return detached entities, edits the result, and awaits `SaveChangesAsync()`. It looks identical to a working update. It survives handler tests that **mock the repository** and e2e tests that assert only the **HTTP status** without reading the row back. The pattern travels in packs — bulk update, soft-delete, bulk soft-delete siblings.

## Bad

```csharp
// Context default is QueryTrackingBehavior.NoTracking.
public async Task<bool> UpdateTemplateAsync(CorrelationTemplate input, CancellationToken ct)
{
    var entity = Ctx.GetCorrelationRules(ids: new[] { input.Id }).FirstOrDefault(); // detached
    if (entity is null) return false;
    entity.Name = input.Name;             // change tracker never sees this
    await Ctx.SaveChangesAsync(ct);        // 0 rows written; returns success anyway
    return true;
}
```

## Good

```csharp
var entity = Ctx.GetCorrelationRules(ids: new[] { input.Id })
                .AsTracking()              // EF snapshots the entity (and Included children)
                .FirstOrDefault();
// mutate...
await Ctx.SaveChangesAsync(ct);            // now emits UPDATE; affected-rows > 0
```

Prefer `.AsTracking()` on the fetch (also tracks `Include`d child graphs). For a scalar-only update, `Ctx.Update(entity)` or `Ctx.Entry(entity).State = EntityState.Modified` marks it modified (note: `Update` dirties *every* scalar and won't reach detached children). **Never** flip the context's global default to `TrackAll` to "fix" one path — it regresses read performance everywhere.

## Why it matters

- **Silently dropped write on every mutation** — the `UPDATE`/`DELETE` is never issued and no error is raised. (High, not Critical: a recoverable no-op — re-running the corrected write fixes it, no data corrupted.)
- **Success is falsely reported** — `SaveChangesAsync` returns `0`, not an exception, so the API returns 200/204.
- **Invisible to the usual tests** — mocked-repo handler tests and status-only e2e tests never catch it; only a persistence read-back or affected-rows assertion does.
- **Asymmetric with CREATE** — `Add()` works, masking the bug until someone tests an update/delete against a real DB.

## Fix checklist

- On any write-path fetch under a NoTracking-default context, add **`.AsTracking()`** before materializing.
- For scalar-only updates, alternatively `Ctx.Update(entity)` / set `EntityState.Modified` (aware of its caveats).
- Never change the context's global `UseQueryTrackingBehavior` default to fix a single write path.
- Assert **persistence**, not just HTTP status: check affected-rows > 0 or read the row back — in a repo/integration test, not a mocked-repo handler test.
- Audit sibling write methods that reuse the same read helper.
