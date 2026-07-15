# SRV-L-008 — Copy-paste siblings: near-duplicate members that differ by one operation

| Field | Value |
| --- | --- |
| **Severity** | `[LOW]` |
| **Category** | Code Clarity |

## PR comment template

```
**SRV-L-008 — Copy-paste siblings.** Two+ members are identical except for a single operation/constant/type; extract one parameterized helper so the shared logic (and its future fixes) lives in one place.
```

## Summary

Two or more members — methods, branches, per-type handlers — are near-identical (same structure, guards, error handling, surrounding logic) and differ only in **one operation, constant, or type**. Each copy is a maintenance liability: a fix or change has to be repeated in every sibling, and they drift when someone updates one and forgets the others. Fold the shared body into a single helper and pass the one varying piece — a delegate, a value, or a generic type parameter — as an argument.

## Where it shows up

Paired operation methods (`IncrementAsync`/`DecrementAsync`, `Enable`/`Disable`, `Add`/`Remove`), `switch`/`if` arms that differ by one call, or per-type handlers identical but for the type. The tell: diff two members and the diff is essentially **one token**.

## Bad

```csharp
public async Task IncrementAsync(TModel model)
{
 if (model == null) throw new ArgumentNullException(nameof(model));
 var key = _keyBuilder.BuildKey(model);
 var result = await _db.StringIncrementAsync(key).ConfigureAwait(false); // ← only this line differs
 var ttl = _configuration.ResolveTtlFor(model);
 if (ttl != TimeSpan.Zero) await _db.KeyExpireAsync(key, ttl).ConfigureAwait(false);
 return result;
}

public async Task DecrementAsync(TModel model)
{
 if (model == null) throw new ArgumentNullException(nameof(model));
 var key = _keyBuilder.BuildKey(model);
 var result = await _db.StringDecrementAsync(key).ConfigureAwait(false); // ← …and here
 var ttl = _configuration.ResolveTtlFor(model);
 if (ttl != TimeSpan.Zero) await _db.KeyExpireAsync(key, ttl).ConfigureAwait(false);
 return result;
}
```

## Good

```csharp
// A decrement is just an increment by -1, so the varying piece is a value, not a function:
public Task IncrementAsync(TModel model) => ChangeByAsync(model, +1);
public Task DecrementAsync(TModel model) => ChangeByAsync(model, -1);

private async Task ChangeByAsync(TModel model, long delta)
{
 if (model == null) throw new ArgumentNullException(nameof(model));
 var key = _keyBuilder.BuildKey(model);
 var result = await _db.StringIncrementAsync(key, delta).ConfigureAwait(false); // INCRBY; negative delta = decrement
 var ttl = _configuration.ResolveTtlFor(model);
 if (ttl != TimeSpan.Zero)
 await _db.KeyExpireAsync(key, ttl).ConfigureAwait(false);
 return result;
}
```

The null-check, key build, and TTL handling now exist **once**; only the delta varies. Prefer the **simplest parameterization that fits**: a *value* (as here) beats a *delegate* beats a *generic*. A boolean flag is **not** the simple option — `ChangeAsync(model, true)` just hides the branch you set out to remove. Reach for a `Func<>`/`Action<>` only when the siblings differ by a genuine operation that can't be reduced to a value (e.g. `Save` vs `Delete`), and a generic type parameter when they differ only by type. Either way the shared logic lives in one place, so a later fix can't land in one sibling and miss the others.

## Why it matters

- **Fixes land in one sibling, not the others.** The classic failure: a bug fix (or the TTL change) goes into `IncrementAsync` and someone forgets `DecrementAsync`; the two silently diverge.
- **N-way maintenance.** Every change has to be made in every copy, and reviewers must diff the siblings by eye to confirm they stayed in sync.
- **Hidden inconsistency.** Copies *look* identical, so a stray difference — a missing `ConfigureAwait`, a different flag — hides in the noise.

## When **not** to extract

If the similarity is **coincidental** — two members that look alike today but change for different reasons — forcing a shared helper couples them wrongly and makes future change harder. The test: they differ by exactly one *parameterizable* axis **and** would change together for the same reason. If either isn't true, leave them apart.

## Fix checklist

- Confirm the members differ by exactly one axis (an operation, constant, or type) and change for the same reason.
- Extract the shared body into one helper; pass the varying piece as the simplest thing that fits — a **value** first, then a delegate (`Func<>`/`Action<>`), then a generic type parameter.
- Reduce each sibling to a one-line call into the helper.
- Verify behaviour is unchanged by the extraction — ideally against the existing tests.
