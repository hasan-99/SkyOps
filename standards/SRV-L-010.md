# SRV-L-010 — CancellationToken missing or not threaded through

| Field | Value |
| --- | --- |
| **Severity** | `[LOW]` |
| **Category** | Async/Concurrency |

## PR comment template

```
**SRV-L-010 — CancellationToken missing or not threaded through.** This async method either takes no `CancellationToken` for the cancelable work it awaits, or accepts one and passes it to nothing (CA2016) — so cancellation does nothing. Accept a token and flow it to every awaited call that takes one.
```

## Summary

An async method that awaits cancelable work doesn't plumb cancellation through. Two shapes: **(a) missing** — the method declares no `CancellationToken` parameter, so callers can't cancel it and it can't flow a token to the I/O it awaits; **(b) unused** — it accepts a `CancellationToken` but never passes it on. Either way cancellation is a no-op: request timeouts, client disconnects, and graceful-shutdown signals are ignored and the work runs to completion regardless. An async method that awaits cancelable operations should **take a `CancellationToken` and flow it to everything it awaits**. (Roslyn **CA2016** flags the un-forwarded case.)

## Where it shows up

- **Missing:** `public async Task DoWorkAsync(args)` with no token, whose body does `await db.SaveChangesAsync()` / `await http.GetAsync(url)` — the awaited APIs support cancellation, but the method gives callers no way to trigger it.
- **Unused:** `…, CancellationToken ct = default)` whose body calls `await Foo()` instead of `await Foo(ct)`. The `= default` makes it easy to miss — callers omit the argument and nobody notices the token is inert.

## Bad

```csharp
// (a) MISSING — no token, yet every awaited call is cancelable:
public async Task GetOrderAsync(int id)
{
 var order = await _db.Orders.FirstOrDefaultAsync(o => o.Id == id); // EF *Async takes a token
 order.Rate = await _http.GetFromJsonAsync("/rates"); // HttpClient takes a token
 return order;
}

// (b) UNUSED — token accepted but passed to nothing (CA2016):
public async Task GetOrderAsync(int id, CancellationToken ct = default)
{
 var order = await _db.Orders.FirstOrDefaultAsync(o => o.Id == id); // ct dropped
 order.Rate = await _http.GetFromJsonAsync("/rates"); // ct dropped
 return order;
}
```

## Good

```csharp
public async Task GetOrderAsync(int id, CancellationToken ct)
{
 var order = await _db.Orders.FirstOrDefaultAsync(o => o.Id == id, ct);
 order.Rate = await _http.GetFromJsonAsync("/rates", ct);
 return order;
}
```

Accept a `CancellationToken` and flow it into every awaited call that takes one (and `Task.Delay`, EF `*Async`, `HttpClient`…); in loops, call `ct.ThrowIfCancellationRequested()` between iterations.

**If a dependency doesn't accept a token, you can't "just flow it."** Add `CancellationToken` to that interface/method and thread it down to a leaf that actually supports cancellation. Some leaves genuinely don't — e.g. **StackExchange.Redis** commands take `CommandFlags`, not a per-call `CancellationToken` — so thread the token as far as it goes and stop where the API can't honor it.

**When it's fine to omit:** if a method awaits *nothing cancelable* — pure CPU work, or a call tree that bottoms out only at APIs with no token (e.g. a Redis-only service) — don't add a `CancellationToken` it can't use; and if you find an existing `ct = default` that genuinely can't flow anywhere, **drop it** rather than keep a dead parameter. The violation is the **mismatch**: cancelable work with no token to stop it, or a token that goes nowhere.

## Why it matters

- **Cancellation doesn't cancel.** Request timeouts, client disconnects, and shutdown tokens are ignored; the work runs to the end, holding resources it should have released.
- **Slow or stuck shutdown.** Long operations can't be interrupted, so host shutdown blocks until they finish or time out.
- **The signature misleads.** The *unused* case promises cancellation it doesn't deliver; the *missing* case offers no cancellation surface at all on work that clearly supports it.

## Fix checklist

- If the method awaits cancelable work (DB/HTTP/IO/delays/queues), **accept a `CancellationToken`**.
- Flow it to every awaited call that accepts one; `ThrowIfCancellationRequested()` in loops.
- Never accept a token and drop it (CA2016); never add a token a method can't actually use.
- If a dependency lacks a token overload, thread `ct` down by adding it to that interface/impl, to a leaf that supports cancellation. Where the leaf can't (e.g. StackExchange.Redis), stop there; if *nothing* in the tree can be cancelled, drop the parameter instead of keeping a dead one.
- Enable analyzer **CA2016** to catch un-forwarded tokens at build time.
