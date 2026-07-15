# SRV-O-011 — Private methods ordered below public members

| Field | Value |
| --- | --- |
| **Severity** | `[OPTIONAL]` |
| **Category** | Code Clarity |

## PR comment template

```
**SRV-O-011 — Private methods below public.** Order private/helper members after the type's public API so a reader sees the contract before the implementation details.
```

## Summary

A class declares a **private helper above its public methods**, so a reader opening the file hits implementation detail before the type's public contract. The convention is to order members by descending accessibility — `public` first, then `protected`/`internal`, then `private` — so the public surface (what the type *does*) reads top-to-bottom before the private mechanics (how it does it). Mixing a private helper in ahead of the public API forces the reader to scroll past internals to find the entry points.

## Where it shows up

A helper extracted while editing a class gets dropped in at the cursor — often right at the top of the type, above the constructor's public methods — instead of being moved to the private section at the bottom. It also shows up when public and private members are interleaved with no consistent ordering, so the public API is scattered through the file.

## Bad

```csharp
public class ImpalaAlertLogsManager : IAlertLogsManager
{
 // ..ctor..

 // Private helper placed ABOVE the public API — reader hits an implementation
 // detail before seeing what the type actually exposes.
 private string ResolveEffectiveTableName(Alert alert, string requestTableName)
 => _exceptionRepo.GetTargetTable(alert.CorrelationRuleId) ?? requestTableName;

 public Task RetrieveAlertLogs(AlertLogsRequestVM request, /*..*/) { /* .. */ }

 public Task> RetrieveAlertTables(AlertLogsRequestVM request, /*..*/) { /* .. */ }
}
```

## Good

```csharp
public class ImpalaAlertLogsManager : IAlertLogsManager
{
 // ..ctor..

 public Task RetrieveAlertLogs(AlertLogsRequestVM request, /*..*/) { /* .. */ }

 public Task> RetrieveAlertTables(AlertLogsRequestVM request, /*..*/) { /* .. */ }

 // Private helpers grouped at the bottom, after the full public surface.
 private string ResolveEffectiveTableName(Alert alert, string requestTableName)
 => _exceptionRepo.GetTargetTable(alert.CorrelationRuleId) ?? requestTableName;
}
```

Move private helpers below the public (and any protected/internal) members. Group all the private members together at the end of the type so the public contract reads first. This is a pure reordering — no behaviour changes — and is enforceable with StyleCop `SA1202`.

## Why it matters

- A reader (or reviewer) scanning a type wants the public contract first; leading with private internals buries the entry points and slows comprehension.
- Consistent member ordering makes diffs smaller and review faster — new helpers always land in the same place (the bottom) instead of wherever the cursor was.
- It is mechanically enforceable (`SA1202` / editorconfig), so drift is avoidable and the rule is unambiguous.

## Fix checklist

- Move every `private` method below the last `public`/`protected`/`internal` member of the type.
- Keep helpers grouped together at the end rather than interleaved with the public API.
- Preserve order within an access group (don't reshuffle unrelated members in the same diff).
- Confirm it's a pure move — no signature or body change rode along.
