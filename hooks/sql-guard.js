#!/usr/bin/env node
// SkyOps PreToolUse guard — destructive SQL.
// Fires on Bash tool calls. Only reacts when the command actually EXECUTES SQL
// through a known runner (sqlcmd/psql/mysql/sqlite3/dotnet ef ...) AND that SQL
// is destructive. Reading/grepping a .sql file is never flagged.
//
// Decision: "ask" — surfaces the danger and lets the user confirm; it does not
// hard-block, so a legitimate intentional op is one confirmation away.
//
// Safety-of-the-guard-itself: any parsing/JSON error => allow (exit 0). A hook
// bug must never block the user's work.

"use strict";

let input = "";
process.stdin.on("data", (c) => (input += c));
process.stdin.on("end", () => {
  try {
    const data = JSON.parse(input || "{}");
    const cmd = (data.tool_input && data.tool_input.command) || "";
    if (typeof cmd !== "string" || !cmd.trim()) return allow();

    // Only guard actual SQL execution. If no SQL runner is invoked, we can't
    // claim it's destructive (it might just be reading a migration file).
    const runsSql =
      /\b(sqlcmd|osql|Invoke-Sqlcmd|psql|mysql|mariadb|sqlite3)\b/i.test(cmd) ||
      /\bdotnet\s+ef\s+database\s+(drop|update)\b/i.test(cmd);
    if (!runsSql) return allow();

    const reasons = [];

    if (/\bdotnet\s+ef\s+database\s+drop\b/i.test(cmd))
      reasons.push("`dotnet ef database drop` deletes the database");
    if (/\bDROP\s+(TABLE|DATABASE|SCHEMA|INDEX|VIEW|PROCEDURE|COLUMN)\b/i.test(cmd))
      reasons.push("DROP of a database object");
    if (/\bTRUNCATE\s+TABLE\b/i.test(cmd))
      reasons.push("TRUNCATE empties a table with no WHERE and no easy rollback");
    if (/\bDELETE\s+FROM\b/i.test(cmd) && !/\bWHERE\b/i.test(cmd))
      reasons.push("DELETE FROM with no WHERE deletes every row");
    if (/\bUPDATE\b[\s\S]*\bSET\b/i.test(cmd) && !/\bWHERE\b/i.test(cmd))
      reasons.push("UPDATE ... SET with no WHERE rewrites every row");
    if (/\bALTER\s+TABLE\b[\s\S]*\bDROP\b/i.test(cmd))
      reasons.push("ALTER TABLE ... DROP removes a column/constraint");

    if (!reasons.length) return allow(); // SQL runs, but it's not destructive.

    return ask(
      "SkyOps SQL guard — destructive operation detected:\n  - " +
        reasons.join("\n  - ") +
        "\nSafe alternative: add a specific WHERE (id/tenant/date), prefer a soft delete, " +
        "run SELECT COUNT(*) of the target rows first, or scope the migration. " +
        "See /sky-sql-destructive-guard for the full check."
    );
  } catch (e) {
    return allow(); // never block on our own error
  }
});

function allow() {
  process.exit(0);
}
function ask(reason) {
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "ask",
        permissionDecisionReason: reason,
      },
    })
  );
  process.exit(0);
}
