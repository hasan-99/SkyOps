---
type: command
tags: [command, skyops, guard]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `commands/sky-sql-destructive-guard.md`
**Repo description:** Implementation-time guard that fires when new/edited code or a migration writes destructive SQL — DROP, TRUNCATE, DELETE/UPDATE without WHERE, ALTER ... DROP, EF ExecuteSqlRaw/ExecuteSqlInterpolated with those, Database.EnsureDeleted, a destructive migration Down, or a change that removes a tenant/customer filter. Flags it at the exact line with the scoped, safe alternative before it reaches a PR or a database. Read-only.
**user-invocable:** true · **disable-model-invocation:** false
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# /sky-sql-destructive-guard

Implementation-time guard for destructive SQL/EF operations: DROP, TRUNCATE, DELETE/UPDATE without a WHERE, `ALTER ... DROP`, `ExecuteSqlRaw`/`ExecuteSqlInterpolated` with those, `Database.EnsureDeleted`, a destructive migration `Down`, or a change that removes a tenant/customer filter. `disable-model-invocation: false` — self-fires on matching code.

Write-time counterpart to [[sky-risk]]'s "Hard Gate — Destructive Patterns." Also mirrored at the tool-call level by the `git-guard`/`sql-guard` logic in `guard-dispatch.js` — see [[Hooks]].

## Example

```csharp
// Flags — DELETE with no scoping filter
await _db.Database.ExecuteSqlRawAsync("DELETE FROM Orders WHERE Status = @p0", status);
// if @p0 can be null/unbound this deletes the whole table

// Flags — tenant filter silently dropped
var orders = _db.Orders.IgnoreQueryFilters().Where(o => o.Status == status);

// Fix — scoped, filter-preserving
var orders = _db.Orders.Where(o => o.TenantId == tenantId && o.Status == status);
_db.Orders.RemoveRange(orders);
await _db.SaveChangesAsync(ct);
```

## See also

[[sky-async-guard]] · [[sky-i18n-guard]]
