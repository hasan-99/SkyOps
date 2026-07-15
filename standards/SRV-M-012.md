# SRV-M-012 — Whole-table load to find one row by a translatable key

| Field | Value |
| --- | --- |
| **Severity** | `[MED]` |
| **Category** | Performance |

## PR comment template

```
**SRV-M-012 — Whole-table load to find one row by key.** This pulls the entire table into memory and then picks one row by id/key in client code, paying O(table-size) transfer + allocation per request for what a single indexed `WHERE` would do in the DB. Add a by-key repository method that filters in SQL.
```

## Summary

A handler needs **one row by its key** but the repository only offers a list/get-all method, so the code pulls the **entire table** into memory and selects the row in client code — `repo.GetUsers().FirstOrDefault(u => u.Id == id)`. The predicate is a plain primary/unique-key equality, which translates trivially to an indexed `WHERE`. Instead every row is transferred and materialised so all but one can be discarded — **O(table-size) transfer and allocation for an O(1) lookup**, on every request.

## Where it shows up

A handler/service resolving a single entity by id or unique key, where the repository exposes only `GetAll()`/`GetUsers()`-style methods returning a fully-materialised collection, so the caller filters in LINQ-to-objects. The tell: a get-all call immediately followed by `First`/`Single`/`FirstOrDefault` on a **by-id or by-unique-key equality** predicate.

## The discriminator

- **Not** `SRV-H-001` (sync I/O in async) — that's about blocking a thread; this is about moving a whole table over the wire. They can co-occur; cite each for its own root cause.
- **Not** justified client-side filtering. Some predicates genuinely can't translate to SQL — full-text/substring search, culture-insensitive compare, computed criteria — and pulling a bounded candidate set can be right. The distinguishing fact: a **by-id/by-key equality translates trivially** to an indexed `WHERE`, so loading the whole table is pure waste with no SQL-translation excuse.

## Bad

```csharp
// Repo only offers GetUsers() → entire table fetched and materialised, all rows but one discarded:
var user = _repo.GetUsers().FirstOrDefault(u => u.Id == request.UserId);   // O(table) for an O(1) lookup
```

## Good

```csharp
public Task<User?> GetUserByIdAsync(int id, CancellationToken ct) =>
    _context.Users
        .Where(u => u.Id == id)          // translated to an indexed WHERE — DB returns one row
        .FirstOrDefaultAsync(ct);

// Caller:
var user = await _repo.GetUserByIdAsync(request.UserId, ct);
```

The query stays `IQueryable` until the predicate is applied, so EF composes `Where` + `FirstOrDefault` into one round-trip returning at most one row; only the matching row crosses the wire.

## Why it matters

- **O(table-size) transfer for an O(1) lookup** — every row read, sent, and materialised just to keep one; cost scales with table size, not result size, paid per request.
- **Allocation churn** — the full result set is allocated then discarded (GC pressure); the DB does a scan where an index seek would do.
- **Degrades silently as data grows** — fine on a seed table, linearly worse in production, with no code change to flag it.

## Fix checklist

- Add a by-key repository method (`GetByIdAsync(key, ct)`) that applies the predicate **inside** the query (`Where(...).FirstOrDefaultAsync(ct)`), not after materialisation.
- Keep the source `IQueryable` — don't call `ToList()`/`AsEnumerable()`/get-all before the `Where`/`First`/`Single`.
- Reserve client-side filtering for predicates that genuinely can't translate (keyword/substring/culture-insensitive/computed), and bound the candidate set even then.
- Thread the `CancellationToken` into the async terminal operator.
