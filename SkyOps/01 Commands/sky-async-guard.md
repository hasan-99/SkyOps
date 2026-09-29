---
type: command
tags: [command, skyops, guard, async]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `commands/sky-async-guard.md`
**Repo description:** Implementation-time guard that fires when new/edited code declares an async method or adds an await chain. Checks every DB/HTTP/file call bottoms out at a real *Async API (not sync-call-in-async or Task.Run-wrapped-sync), that private helpers on the async path are async too, and that a CancellationToken is accepted and threaded through. Flags the anti-pattern at the exact line with an inline fix, stopping SRV-H-001 before it's committed.
**user-invocable:** true · **disable-model-invocation:** false
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# /sky-async-guard

Implementation-time guard for **SRV-H-001** (sync I/O in an async method) and **SRV-L-010** (CancellationToken missing or not threaded through). `disable-model-invocation: false` — self-fires the instant a new/edited `async` method or `await` chain is typed, not just when explicitly invoked.

Read-only by default: explains + shows the inline fix, doesn't edit unless asked. Never runs builds/tests/formatters. Not a substitute for [[sky-review]] — full pattern explained in [[Async Change Guard Pattern]].

## Example

```csharp
// Flags — sync call inside an async method (SRV-H-001)
public async Task<Order> GetOrderAsync(int id, CancellationToken ct)
{
    var order = _db.Orders.FirstOrDefault(o => o.Id == id); // sync EF call
    return order;
}

// Flags — Task.Run just relocates the block, doesn't remove it (SRV-H-001)
public async Task<string> ReadFileAsync(string path)
    => await Task.Run(() => File.ReadAllText(path));

// Flags — CancellationToken accepted but never threaded through (SRV-L-010)
public async Task<Order> GetOrderAsync(int id, CancellationToken ct)
{
    return await _db.Orders.FirstOrDefaultAsync(o => o.Id == id); // ct dropped
}

// Fix
public async Task<Order> GetOrderAsync(int id, CancellationToken ct)
{
    return await _db.Orders.FirstOrDefaultAsync(o => o.Id == id, ct);
}
```

## See also

[[sky-i18n-guard]] · [[sky-sql-destructive-guard]] · [[sky-service]] · [[sky-review-service]] · [[SRV Catalog]]
