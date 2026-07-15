# SRV-H-006 — Culture/timezone-dependent DateTime parsing & formatting

| Field | Value |
| --- | --- |
| **Severity** | `[HIGH]` |
| **Category** | Globalization |

## PR comment template

```
**SRV-H-006 — Culture/timezone-dependent DateTime.** `DateTime.Parse/TryParse/ToString` without `CultureInfo.InvariantCulture` + `DateTimeStyles` makes the result depend on the server's locale/timezone (and `Kind == Unspecified` + `ToUniversalTime()` shifts by the server's offset). Pass invariant culture and UTC styles.
```

## Summary

A `DateTime` is parsed, formatted, or converted without specifying a culture and `DateTimeStyles`, so the result depends on **ambient machine state** — the server's locale and timezone — instead of on the data. `DateTime.Parse`/`TryParse` default to `CultureInfo.CurrentCulture`, so `01/02/2024` is 2 Jan on `en-US` but 1 Feb on `en-GB`. A parsed value also comes back with `Kind == Unspecified`, and `ToUniversalTime()` then treats it as **server-local** and shifts it by that machine's UTC offset. Same input, different output per machine — and it's invisible on a dev box that happens to be `en-US`/UTC.

## Where it shows up

Parsing timestamps or numbers from logs, files, external APIs, or text DB columns with bare `DateTime.Parse(s)` / `decimal.Parse(s)`; formatting with `.ToString()` for storage, keys, or comparison; and `ToUniversalTime()` on a freshly parsed `Unspecified`-kind value. The same defect class covers `string.ToLower()`/`Compare` without `InvariantCulture` (the Turkish-İ problem) in key normalisation — dates are just the most common and most damaging instance.

## Same input, different machine

```
"01/02/2024 13:00" ─┬─► en-US server ─► 2 Jan 2024 13:00
 └─► en-GB server ─► 1 Feb 2024 13:00 ← locale changed the DATE

parsed Kind = Unspecified, then .ToUniversalTime():
 on a UTC server ─► 13:00Z
 on a UTC+2 server ─► 11:00Z ← server TZ changed the INSTANT
```

## Bad

```csharp
// NormalizeTimestampFields: parse defaults to CurrentCulture; Kind is Unspecified;
// ToUniversalTime() then assumes SERVER-LOCAL and shifts by the machine's offset.
if (row[key] is string s && DateTime.TryParse(s, out var dt))
 row[key] = dt.ToUniversalTime().ToString("o"); // wrong UTC on any non-UTC server

// ExtractCanonicalTimestamp: same defect when choosing the row's instant.
if (DateTime.TryParse(val.ToString(), out var dt2))
 return dt2.ToUniversalTime();
```

## Good

```csharp
// Invariant culture + explicit styles: neither the server's locale nor its timezone matters.
if (row[key] is string s &&
 DateTime.TryParse(s, CultureInfo.InvariantCulture,
 DateTimeStyles.AdjustToUniversal | DateTimeStyles.AssumeUniversal, out var dt)) // dt.Kind == Utc
 row[key] = dt.ToString("o", CultureInfo.InvariantCulture);

if (DateTime.TryParse(val.ToString(), CultureInfo.InvariantCulture,
 DateTimeStyles.AdjustToUniversal | DateTimeStyles.AssumeUniversal, out var dt2))
 return dt2; // already UTC — no blind ToUniversalTime()
```

`AssumeUniversal` stops `ToUniversalTime()` from silently applying the server's local offset when the string carries no zone; `AdjustToUniversal` honours an offset when one *is* present. For an instant, prefer `DateTimeOffset`. Use `InvariantCulture` everywhere data is machine-readable; reserve `CurrentCulture` for strings shown to a human.

## Why it matters

- **Wrong timestamps ship silently.** A parsed `Unspecified` value through `ToUniversalTime()` is shifted by the server's UTC offset — logs land hours off, ordering and time-windows break, audit trails lie. No exception, no log.
- **Locale-dependent parsing.** `01/02/2024` is a different date across `en-US`/`en-GB`; numeric parsing flips `.` and `,` as decimal vs thousands separator. The data didn't change — the server did.
- **Latent until deployment changes.** Passes on an `en-US`/UTC dev box, breaks when deployed to another region or a container with a different locale — the worst kind of "works on my machine."
- **String normalisation too.** `ToLower()`/`Compare` without `InvariantCulture` hit the Turkish-İ class of bugs when used to build keys or equality.

## Fix checklist

- Pass `CultureInfo.InvariantCulture` to every machine-data `Parse`/`TryParse`/`ToString` (dates, numbers, bools).
- Pass `DateTimeStyles` explicitly — `AdjustToUniversal | AssumeUniversal` (or `RoundtripKind` for `o`/ISO inputs) — so `Kind` is never left `Unspecified`.
- Never call `ToUniversalTime()` on a value whose `Kind` you didn't set; prefer `DateTimeOffset` for instants.
- Use `StringComparison.OrdinalIgnoreCase` / `ToLowerInvariant()` for key/identifier normalisation.
- Reserve `CurrentCulture` strictly for text rendered to an end user.
- Enable analyzers **CA1305** (specify `IFormatProvider`), **CA1304**/**CA1310** (specify culture/`StringComparison`) to catch new occurrences at build time.
