---
type: command
tags: [command, skyops, guard]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `commands/sky-i18n-guard.md`
**Repo description:** Implementation-time guard for culture/timezone-dependent DateTime and numeric parsing/formatting (SRV-H-006). Fires the moment new or edited code calls DateTime.Parse/TryParse/ToString, decimal/numeric Parse, ToLower/Compare for key normalization, or ToUniversalTime() without explicit InvariantCulture/DateTimeStyles/OrdinalIgnoreCase, so the defect is caught while typing instead of weeks later in review.
**user-invocable:** true · **disable-model-invocation:** false
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# /sky-i18n-guard

Implementation-time guard for **SRV-H-006** — culture/timezone-dependent parsing/formatting. `disable-model-invocation: false` — self-fires on `DateTime.Parse/TryParse/ToString`, numeric `Parse`, `.ToLower()`/`Compare` used for key normalization, or `.ToUniversalTime()` — all when used without explicit `InvariantCulture`/`DateTimeStyles`/`OrdinalIgnoreCase`.

Same write-time-guard pattern as [[sky-async-guard]]: explains + shows the inline fix, read-only by default.

## Example

```csharp
// Flags — culture/locale-dependent parsing (SRV-H-006)
var due = DateTime.Parse(dto.DueDate);
var amount = decimal.Parse(dto.Amount);
var key = customerCode.ToLower(); // locale-dependent casing, e.g. Turkish "I"

// Fix
var due = DateTime.Parse(dto.DueDate, CultureInfo.InvariantCulture, DateTimeStyles.None);
var amount = decimal.Parse(dto.Amount, NumberStyles.Number, CultureInfo.InvariantCulture);
var key = customerCode.ToUpperInvariant();
```

## See also

[[sky-async-guard]] · [[sky-sql-destructive-guard]] · [[SRV Catalog]] · [[Async Change Guard Pattern]]
