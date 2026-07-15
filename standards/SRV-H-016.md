# SRV-H-016 — Shared EF entity: a schema change reaches only some of the databases it is mapped to

| Field | Value |
| --- | --- |
| **Severity** | `[HIGH]` |
| **Category** | Data/Persistence |

## PR comment template

```
**SRV-H-016 — Shared entity schema change misses a backing DB.** A shared EF entity mapped in multiple contexts (each pointing at a different database) gets a column added in only some backing DBs, so the un-migrated DB throws "Invalid column name"/"Unknown column" at query time. Migrate every mapped DB, or `Ignore()` the property in the context whose DB won't have it.
```

## Summary

A single EF entity is mapped in **more than one `DbContext`, each pointing at a different physical database**. When you add a mapped property (or make one non-optional) on that shared entity, EF emits that column in the SQL it generates for **every** context the entity is mapped in — including reads. If the DDL was applied to only one backing database, every query against the others throws `Invalid column name` (SQL Server) / `Unknown column` (MySQL) at **runtime** — with a passing build and a green local run against the one DB you developed against.

The `CorrelationRule`-style entities are the canonical case: the same .NET type is mapped by `ProjectContext` to the per-tenant `Col_*` DB (SQL Server) **and** by `iCollectorContext` to `CorrelationRulesNew` (collector, MySQL). A change to the deployed rule has **two** backing DBs to hit (tenant + collector); one spanning the template type touches **three**.

## Where it shows up

A DB-first entity (schema shipped as hand-written SQL runbooks, no EF migrations) carrying a `ToTable(...)` in two contexts. The tell: a new property, a `Property(...)` mapping added in one context, and a migration runbook labelled for some DBs but never naming the other mapped table (e.g. the collector `CorrelationRulesNew`) — even though the same entity is mapped there **without** an `Ignore(...)`. Check base contexts (`ProjectContext_Base`) to find every context that binds the type.

## Bad

```csharp
// New column on the SHARED entity, mapped by BOTH ProjectContext and iCollectorContext:
public SeveritySource? SeveritySource { get; private set; }

// ProjectContext (tenant Col_*, SQL Server) — column mapped + migrated.
modelBuilder.Entity<CorrelationRule>(e => e.Property(x => x.SeveritySource).HasColumnType("tinyint"));

// iCollectorContext (SAME entity → CorrelationRulesNew, MySQL). NOT Ignore()d,
// so EF will SELECT SeveritySource here — but the runbook never ALTERs CorrelationRulesNew.
modelBuilder.Entity<CorrelationRule>(e => e.ToTable("CorrelationRulesNew"));
// → collector reads throw MySQL "Unknown column 'SeveritySource'" at runtime.
```

## Good

```csharp
// Either migrate EVERY backing DB the entity is mapped in (treat tenant + collector as a PAIR):
//   each Col_<project> : ALTER TABLE dbo.CorrelationRules ADD SeveritySource TINYINT NULL;
//   collector MySQL    : ALTER TABLE CorrelationRulesNew   ADD SeveritySource TINYINT NULL;  -- the paired change
// (add OdManagement when the template type carries the field too). Keep new columns nullable + EF-optional.

// OR opt a context out explicitly so EF never references the column there:
modelBuilder.Entity<CorrelationRule>(e =>
{
    e.ToTable("CorrelationRulesNew");
    e.Ignore(x => x.SeveritySource);   // collector DB won't have it → EF never SELECTs it here
});
```

Close the loop everywhere or opt one out explicitly. What you cannot do is add a mapped property and migrate only the DB you happened to develop against.

## Why it matters

- **Runtime crash across a whole store** — `Invalid column name`/`Unknown column` on the first query that materializes the entity; every read against the un-migrated DB 500s.
- **Blast radius is every tenant / the whole collector** — one skipped `ALTER` breaks many tenants or the entire collector path at once.
- **Silent until the other assembly runs** — builds/tests pass, local run against the one migrated DB looks green; the failure appears when deployed code queries the other store.
- **`Ignore()` was the cheap alternative** — one line would have avoided a cross-store outage.

## Fix checklist

- List **every** `DbContext` the entity is mapped in (grep the type; check base contexts). Confirm which entity type each context binds.
- For each mapped context, the new property is either backed by a real column in that context's DB **or** `Ignore()`d there.
- Migrate the **pair** (tenant `Col_*` + collector `CorrelationRulesNew`); add OdManagement if the template type has the field.
- Make additive columns nullable in the DB and EF-optional so a staged rollout tolerates the column being present on some DBs first.
- Search the runbook for the other mapped table name — if a shared-entity column change doesn't mention it, the pair is incomplete.
- Treat the change as **deploy-coupled**: DDL on all backing DBs lands in lockstep with the assembly that adds the mapping.
