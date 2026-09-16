---
id: dev-db-access
title: Dev database access
status: stable
---

# Dev database access (all sessions, all projects)

A dev SQL Server is available for verifying schema/data on any Jira. Do not ask for credentials each time.

- **Read-only.** For a DB check, connect and READ only (SELECT / `INFORMATION_SCHEMA`). NEVER run UPDATE / INSERT / DELETE / DDL against the database.
- **DB changes go to a `.sql` file.** When a Jira involves a DB change (new column, migration, data fix), do NOT execute it — write a reviewed `.sql` migration/query file in the appropriate folder instead.
- Key DBs: `ClearSkies`, `New_Collect`, and 8 `Col_*` per-customer DBs. The asset table is `dbo.Devices` (PK `Id`).
- No connection string exists in the repos (they read a vault at runtime), so connect directly with `sqlcmd`.
- **Never print the credential.** Not in a report, not in a Jira comment, not to confirm you have it. Pass it to `sqlcmd` and nothing else.

The connection details are machine-local and are spliced in below from `~/.claude/skyops-secrets.local.md`, which is never stored in the SkyOps repository.

{{SKYOPS_SECRETS}}
