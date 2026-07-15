# SRV-L-002 — Helper re-checks an invariant the caller already enforces

| Field | Value |
| --- | --- |
| **Severity** | `[LOW]` |
| **Category** | Code Clarity |

## PR comment template

```
**SRV-L-002 — Helper re-checks an invariant the caller already enforces.** Re-applying a rule the caller already enforced is dead defensive code with two sources of truth.
```

## Summary

A helper accepts parameters whose relationship is already enforced by the caller, then re-applies that relationship defensively inside its body. The code works *today* — but the invariant now lives in two places, the helper's signature implies the parameters are independent when they aren't, and any drift between caller and helper will silently produce wrong results instead of a loud failure.

## Where it shows up

Helpers extracted from a larger method that pull every caller-local variable into the signature. Typically a boolean and a related nullable arrive together (`isCrossTenant` + `projectId`, `useDefault` + `overrideValue`, `isAnonymous` + `userId`) and the helper guards "just in case" against a state the caller already excluded.

## Bad

```csharp
// Caller establishes the relationship between the two parameters:
var isCrossTenant = !_tenantContext.Project.IsInitialized;
int? projectId = isCrossTenant ? null : _tenantContext.Project.Id;
var analystId = await ResolveAnalystAsync(isCrossTenant, projectId, ct);

// Helper re-applies the same relationship defensively:
private async Task ResolveAnalystAsync(
 bool isCrossTenant,
 int? projectId,
 CancellationToken ct)
{
 var analysts = await _repo.GetAnalysts(
 projectId: isCrossTenant ? null : projectId, // redundant — projectId is already null when isCrossTenant
 isInternalAnalyst: isCrossTenant,
 cancellationToken: ct);

 return analysts.SingleOrDefault()?.Id;
}
```

## Good

```csharp
// Helper takes only the canonical input and derives the rest from it:
private async Task ResolveAnalystAsync(
 int? projectId,
 CancellationToken ct)
{
 var analysts = await _repo.GetAnalysts(
 projectId: projectId,
 isInternalAnalyst: projectId is null,
 cancellationToken: ct);

 return analysts.SingleOrDefault()?.Id;
}
```

The helper now has one source of truth (`projectId`). Cross-tenant-ness is derived locally where it's used, the signature no longer lies about parameter independence, and there's no defensive ternary to drift.

If the boolean parameter must stay (interface contract, multiple callers), add an assertion at the boundary instead of a silent guard:

```csharp
Debug.Assert(isCrossTenant == (projectId is null),
 "isCrossTenant and projectId must agree at the call boundary.");
```

## Additional example — a special-case branch the general path already covers

The pattern isn't limited to parameters. Any guard that reproduces what the surrounding expression already does is the same redundancy — here a pagination calc special-cases `0`:

```csharp
// Bad — the `== 0` branch is redundant: the formula already returns 0 when totalItems is 0.
TotalPages = totalItems == 0 ? 0 : (int)Math.Ceiling(totalItems / (double)pageSize);

// Good — one expression, and guard the precondition that actually matters instead:
if (pageSize <= 0) throw new ArgumentOutOfRangeException(nameof(pageSize));
TotalPages = (int)Math.Ceiling(totalItems / (double)pageSize);
```

`Math.Ceiling(0 / (double)pageSize)` is already `0`, so the special case adds nothing. Worse, it draws attention away from the *real* missing guard: `pageSize <= 0` divides by zero in `double` → `Infinity` → a garbage negative `TotalPages`. Redundant guards crowd out the ones that count.

## Why it matters

- **Drift is silent.** If the caller's rule changes (e.g. `projectId` becomes optional in non-cross-tenant mode), the helper's defensive ternary keeps "working" while quietly returning wrong data instead of failing loudly.
- **Signature lies.** A reader sees two independent-looking parameters and has to reverse-engineer the rule that ties them together. Every new caller has to relearn the rule.
- **New call sites quietly do the wrong thing.** Anyone calling with `(isCrossTenant: false, projectId: null)` gets a partially cross-tenant query — no exception, no log, just a wrong result.
- **Refactors stall.** "Is this parameter actually used or just here for symmetry?" becomes a question reviewers can't answer from the code alone.

## Fix checklist

- Identify the canonical source of the invariant (usually the nullable — it carries more information than the boolean).
- Drop the redundant parameter from the helper and derive it locally where needed.
- If both parameters must stay (interface constraint), replace the defensive guard with an explicit assertion that they agree.
- Verify all call sites still compile and read naturally with the trimmed signature.
