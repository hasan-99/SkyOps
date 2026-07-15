# SRV-M-007 — Cache write and its TTL set non-atomically

| Field | Value |
| --- | --- |
| **Severity** | `[MED]` |
| **Category** | Caching |

## PR comment template

```
**SRV-M-007 — Cache write and TTL set non-atomically.** The write and its `EXPIRE` are two separate commands, so a crash/cancel/exception between them leaves the key with **no TTL** — it never expires, and orphaned keys grow the keyspace unbounded. Set value+TTL in one command (`SET … EX`), or group the write and its `EXPIRE` in a transaction (`MULTI`/`EXEC`).
```

## Summary

A cache write and the command that sets its expiry are issued as **two separate, non-atomic operations** — a write followed by a distinct `EXPIRE`/`KeyExpire`. If the process crashes, the request cancels, or an exception is thrown **between** the two, the write has already landed but the expiry never runs: the key persists with **no TTL** and is never reclaimed. Over time these orphaned keys accumulate and grow the keyspace without bound. The fix is to make the write and its TTL a **single atomic operation**.

## Where it shows up

Cache repositories that write a key and then call a separate expiry command — value caches (`StringSetAsync` *without* the `expiry:` overload, then `KeyExpireAsync`), counters (`StringIncrementAsync` + `KeyExpireAsync`), hashes/lists/sets. The tell: an `EXPIRE` issued as its own round-trip *after* the write that created the key.

## The leak window

```
write key ──✔──► [ crash / cancel / exception before EXPIRE ] ──► EXPIRE never runs
 key persists with NO TTL → never reclaimed
```

## Bad

```csharp
var key = _keyBuilder.BuildKey(model);
await _db.StringIncrementAsync(key); // (1) key created/bumped — committed now
// ⟵ crash / cancel / exception here
var ttl = _configuration.ResolveTtlFor(model);
if (ttl != TimeSpan.Zero)
 await _db.KeyExpireAsync(key, ttl); // (2) separate command — may never run → key left with no TTL
```

## Good

```csharp
// Value cache: set value AND TTL in ONE command — they commit together or not at all.
await _db.StringSetAsync(key, payload, expiry: ttl);

// Counter (INCR carries no TTL parameter): queue INCR + EXPIRE in one transaction (MULTI/EXEC)
// so they run as a unit — either both apply or neither, with no leak window:
var tran = _db.CreateTransaction();
var incr = tran.StringIncrementAsync(key); // capture the task to read the result after EXEC
_ = tran.KeyExpireAsync(key, ttl);
await tran.ExecuteAsync();
var value = await incr;
```

Both forms guarantee the key never exists without its TTL: `SET … EX` carries the expiry in the write itself, and the `MULTI`/`EXEC` transaction sends the write and its `EXPIRE` as one unit the server runs atomically. There is no window in which the key is written but unexpired.

## Why it matters

- **Orphaned, never-expiring keys.** A crash, cancellation, or exception between the write and the `EXPIRE` leaves a key with **no TTL**. It lives until manual deletion or eviction — no error, no signal.
- **Unbounded keyspace growth.** Orphaned keys accumulate over time; Redis eventually hits `maxmemory` and starts evicting *other* (correctly-TTL'd) keys or rejecting writes.
- **An extra round-trip.** The non-atomic form also costs two commands where one would do.

## Fix checklist

- Prefer the write command that **carries the TTL** (`StringSetAsync(key, value, expiry: ttl)` / `SET … EX`/`PX`).
- When the write has no TTL parameter (`INCR`, list/hash/set ops), group write + expire in a single **transaction** (`MULTI`/`EXEC`) so they apply together.
- Never rely on a follow-up `EXPIRE` that a crash, cancellation, or exception can skip.
