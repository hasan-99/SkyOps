# SRV-M-013 — Server-side grid loads the whole table, then filters/sorts/pages in memory

| Field | Value |
| --- | --- |
| **Severity** | `[MEDIUM]` |
| **Category** | Performance |

## PR comment template

```
**SRV-M-013 — Grid loads the whole table then filters/sorts/pages in memory.** The scope/filter/sort could translate to SQL but the repo does `ToListAsync()` first and applies them with LINQ-to-Objects, so every page pulls the entire table into memory. Push scope + filter + sort into the `IQueryable`.
```

## Summary

A server-driven list/grid endpoint materialises the **whole table** (`ToListAsync()`/`.ToList()`) and then applies ownership scope, filters, search, sort, and paging with **LINQ-to-Objects** over the in-memory list. The database returns every row on every call; the server does the work the database is built for. It scales with **table size, not page size** — the opposite of what a paged grid needs. This is the multi-row grid cousin of `SRV-M-012` (single-row by-key). Here the predicates are grid filters (type/status/severity/search) and an ORDER BY + page — all trivially translatable to SQL.

## Where it shows up

Repositories/services backing an infinite-scroll or paged grid whose context method returns `IQueryable<T>`, but the code calls `.ToListAsync()` early (often to reuse an existing "get all with includes" method), then filters/sorts/pages the resulting `IEnumerable<T>`. An opaque in-memory cursor (`FindIndex(id) → Skip/Take`) is a frequent tell — the cursor is fine, but it's slicing an already-fully-materialised list.

## Bad

```csharp
// Pulls EVERY non-deleted row (plus includes) into memory …
var all = await Ctx.GetCorrelationRules(deleted: false)
    .Include(x => x.ThreatTaxonomy)
    .ToListAsync(ct);

// … then scope/filter/search/sort run as LINQ-to-Objects over the whole list.
IEnumerable<CorrelationRule> q = all.Where(x => IsInOwnershipScope(x, serviceProviderId));
if (statuses?.Length > 0) q = q.Where(x => set.Contains(x.LifecycleStatus.Value));
if (!string.IsNullOrWhiteSpace(search))
    q = q.Where(x => x.Name.Contains(search, StringComparison.OrdinalIgnoreCase)); // in-memory only
return ApplySort(q, sort, sortDir).ToList();
```

The page shown is 50 rows, but the DB shipped and the server materialised all of them (thousands), on every request.

## Good

```csharp
IQueryable<CorrelationRule> q = Ctx.GetCorrelationRules(deleted: false)
    .Include(x => x.ThreatTaxonomy);

q = q.Where(x => serviceProviderId == null || x.ServiceProviderId == serviceProviderId); // scope in SQL
if (statuses?.Length > 0) q = q.Where(x => statusSet.Contains(x.LifecycleStatus.Value));
if (!string.IsNullOrWhiteSpace(search))
    q = q.Where(x => EF.Functions.Like(x.Name, $"%{search}%"));                          // → SQL LIKE
q = ApplySortQueryable(q, sort, sortDir).ThenBy(x => x.Id);                              // ORDER BY in SQL

return await q.ToListAsync(ct);   // materialise only the scoped/filtered/sorted set (then page)
```

Even better, push the page to SQL — keyset `q.Where(x => x.Id > afterId).Take(limit)` (or `Skip/Take`). An in-memory cursor slice is acceptable **only** over an already-filtered, bounded set.

## Why it matters

- **Every request transfers the entire table** and allocates it (rows + all `Include`d sidecars), regardless of page size — memory/GC scale with row count.
- **Latency grows with the library, not the page** — a 50-row page blows its P95 target as the table reaches thousands of rows.
- **`string.Contains(…, StringComparison)` and other in-memory-only predicates silently prevent SQL translation**, blocking a later "just make it IQueryable" fix without rewriting the predicates.
- **Amplified when shared** — KPI/aggregate/export callers reusing the same "load all" method each re-pull the whole table.

## Fix checklist

- Keep the context method returning `IQueryable<T>`; do **not** `ToListAsync()` before filtering.
- Express scope, filters, and search as `Where(...)` on the `IQueryable` (use `EF.Functions.Like`/plain `Contains` — not the `StringComparison` overload — so they translate).
- Do `OrderBy`/`ThenBy(x => x.Id)` on the `IQueryable` so ORDER BY runs in SQL.
- Page in SQL (keyset `WHERE key > @after … TOP (n)` or `Skip/Take`); reserve any in-memory cursor for an already-filtered set.
- Verify with the EF logger / SQL profiler that a filtered request emits `WHERE`/`ORDER BY`/`TOP` and returns page-sized rows — not a full-table `SELECT`.
