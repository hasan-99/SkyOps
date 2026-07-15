# SRV-L-015 — Verbose, redundant comments that restate the code and repeat a narrative

| Field | Value |
| --- | --- |
| **Severity** | `[LOW]` |
| **Category** | Code Clarity |

## PR comment template

```
**SRV-L-015 — Verbose, redundant comments.** The comment restates the code and repeats the same ticket/design narrative already carried on nearby members; comment the *why* in one concise line, link the authoritative doc/ticket once, and let self-documenting names carry the rest.
```

## Summary

A member is annotated with a multi-paragraph comment that (a) restates what the code plainly does, and/or (b) re-tells the same ticket-by-ticket design narrative — the same CLS reference, the same rationale — on every field, method, and mapper that touches the feature. The knowledge is duplicated across many comment sites and duplicated again against the doc it cites. Each copy is comment debt: it drifts from the code and from the linked doc, drowns the one line that actually earns its place (the non-obvious *why*), and makes reviews longer. Comment the *why* once, concisely; put the narrative in the doc you already link; let the names carry the *what*.

## Where it shows up

A feature delivered under one ticket where a reference block gets pasted onto every member it touches (a legacy column, its mapper, each write-path method all carry the same paragraph). Also a repository where one genuine gotcha (e.g. "global NoTracking → `.AsTracking()`", see SRV-H-014) is re-explained in full on every method, or an environmental fact restated at every call site. The tell: two comment blocks a screen apart say the same thing, or the comment reads as an English transcript of the line beneath it.

## Bad

```csharp
// CLS-13844 / v1.4.0 — legacy single-technique scalar. MITRE is now many-to-many; this column is
// RETAINED and dual-written for region-sync / legacy engine / scoring readers. Removal tracked in the
// Decommission Plan (Confluence 1066205186). CLS-13855 — nullable so a techniqueless template mirrors
// NULL (not 0); a NULL FK is not checked, so the FK stays intact and the empty-technique INSERT crash goes away.
[Obsolete("kept for legacy readers; see Decommission Plan", false)]
public int? ThreatTaxonomyId { get; set; }

// ...and the SAME narrative again, in full, on setThreatTaxonomies(...) and applyTemplateUpdate(...).
```

## Good

```csharp
// Legacy scalar, dual-written from the primary technique; NULL when techniqueless.
// Retained for legacy readers — retirement tracked in the Decommission Plan: Confluence 1066205186.
[Obsolete("use CorrelationRuleThreatTaxonomies join; see Decommission Plan (Confluence 1066205186)", false)]
public int? ThreatTaxonomyId { get; set; }

/// <summary>Authoritative writer of the technique join set and the legacy scalar mirror (index 0 = primary).</summary>
public void SetThreatTaxonomies(IReadOnlyList<int> taxonomyIds) { /* ... */ }
```

For a repeated gotcha, state it once at the class/base-context level and leave a two-word pointer at each site, not a paragraph:

```csharp
// This context defaults to NoTracking (see BaseContext); write-path fetches use .AsTracking() — see SRV-H-014.
... .AsTracking(); // write path — see class note
```

## Why it matters

- **Comment rot** — every duplicated paragraph is a copy that must be updated in lockstep; the next edit fixes one and leaves the others stale, so comments contradict each other and the code.
- **Drift from the linked doc** — the same narrative inline and in the doc diverges; readers can't tell which is authoritative.
- **Signal-to-noise** — a screen of prose restating the code buries the one non-obvious sentence that mattered.
- **Slower reviews** — reviewers re-read the same paragraph on five members; cost scales with the number of copies.
- **The "what" goes out of date fastest** — a comment that transcribes the line beneath it is wrong the moment that line changes.

## Fix checklist

- Delete comments that restate the code; keep only the *why* the code cannot express.
- Put the design narrative in the authoritative doc/ticket and link it **once** — not on every field, method, and mapper.
- Collapse a repeated gotcha to a single class-level (or base-type) note; leave a short pointer at each site.
- Prefer a self-documenting name over a comment; rename rather than annotate.
- For a public API, a one-line `<summary>` beats a multi-paragraph block.
- After editing code, check the comment still holds — if it can drift silently, it's probably restating the code.
