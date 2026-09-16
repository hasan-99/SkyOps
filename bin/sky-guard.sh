#!/usr/bin/env bash
# SkyOps PreToolUse guard - destructive git and SQL, in one script.
#
# Ported from hooks/git-guard.js + hooks/sql-guard.js, which were never wired
# because SkyOps is not loaded as a plugin. They are merged here because each
# hook costs a process spawn on every Bash call, and a spawn is the slow part on
# this machine - one script doing both work is half the overhead of two.
#
# node is deliberately NOT used: node.exe takes 20-40s to start here (Defender
# scans the 87MB binary), which on a PreToolUse hook would delay every command.
#
# Decision is always "ask", never a hard block: it surfaces the danger and lets
# the user confirm. Any error exits 0 (allow) - a guard bug must never block work.
#
# Fast path: if the command mentions neither git nor a SQL runner, this exits
# after two substring tests, before any regex runs.

IFS= read -r -d '' -t 10 input 2>/dev/null
[[ -z $input ]] && exit 0

# ---- fast path, FIRST ---------------------------------------------------------
# Test the raw payload for the trigger words before doing anything else. The
# extraction regex below is the expensive part of this script (backtracking over
# an escaped-string alternation), and the overwhelming majority of Bash calls are
# neither git nor SQL - they must not pay for it. Substring tests on a shell
# variable are builtin and effectively free.
lc=${input,,}
[[ $lc != *git* && $lc != *sqlcmd* && $lc != *osql* && $lc != *invoke-sqlcmd* \
   && $lc != *psql* && $lc != *mysql* && $lc != *mariadb* && $lc != *sqlite3* \
   && $lc != *"dotnet ef"* ]] && exit 0

# Pull tool_input.command out of the payload, tolerating escaped characters.
if [[ $input =~ \"command\"[[:space:]]*:[[:space:]]*\"((\\.|[^\"\\])*)\" ]]; then
  cmd=${BASH_REMATCH[1]}
else
  exit 0
fi
[[ -z $cmd ]] && exit 0
lc=${cmd,,}

shopt -s nocasematch
reasons=()
add() { reasons+=("$1"); }

# ---- git --------------------------------------------------------------------
if [[ $lc == *git* ]]; then

  if [[ $cmd =~ git[[:space:]]+push ]]; then
    # --force is dangerous; --force-with-lease is the safe form and is allowed.
    if [[ $cmd == *--force* && $cmd != *--force-with-lease* ]]; then
      add "force push overwrites remote history"
    elif [[ $cmd =~ (^|[[:space:]])-f([[:space:]]|$) ]]; then
      add "force push overwrites remote history"
    fi
    [[ $cmd =~ (main|master)([[:space:]]|$) ]] && \
      add "pushing directly to main/master (prefer a feature branch + review)"
    [[ $cmd == *--delete* ]] && add "deleting a remote branch/ref"
  fi

  [[ $cmd =~ git[[:space:]]+reset[^\|]*--hard ]] && \
    add "git reset --hard discards uncommitted work"

  [[ $cmd =~ git[[:space:]]+clean[^\|]*-[a-z]*f ]] && \
    add "git clean -f deletes untracked files"

  [[ $cmd =~ git[[:space:]]+branch[^\|]*[[:space:]]-D([[:space:]]|$) ]] && \
    add "git branch -D force-deletes a branch (may lose unmerged commits)"

  # git checkout .  /  git checkout -- .
  [[ $cmd =~ git[[:space:]]+checkout[[:space:]]+(--[[:space:]]+)?\.([[:space:]]|$) ]] && \
    add "git checkout . discards every local change in the working tree"

  [[ $cmd =~ git[[:space:]]+restore ]] && [[ $cmd != *--staged* ]] && \
    [[ $cmd =~ (\.|[[:space:]]--[[:space:]]) ]] && \
    add "git restore discards working-tree changes"

  [[ $cmd =~ git[[:space:]]+(filter-branch|filter-repo) ]] && \
    add "history rewrite across the repo"

  [[ $cmd =~ git[[:space:]]+stash[[:space:]]+drop ]] && \
    add "git stash drop deletes a stash permanently"

  # Committing straight onto an integration branch. Only pay for the branch
  # lookup when the command is actually a commit - it costs a process fork.
  if [[ $cmd =~ git[[:space:]]+commit ]]; then
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [[ $branch == "dev" || $branch == "Dev" || $branch == "main" || $branch == "master" ]]; then
      add "committing directly on '$branch' - SkyOps convention is a HJ/CLS-<num>_<desc> branch off latest dev"
    fi
  fi
fi

# ---- sql --------------------------------------------------------------------
# Only when SQL is actually EXECUTED by a runner. Reading or grepping a .sql file
# is never flagged.
if [[ $lc =~ (sqlcmd|osql|invoke-sqlcmd|psql|mysql|mariadb|sqlite3) || \
      $lc =~ dotnet[[:space:]]+ef[[:space:]]+database[[:space:]]+(drop|update) ]]; then

  [[ $cmd =~ dotnet[[:space:]]+ef[[:space:]]+database[[:space:]]+drop ]] && \
    add "\`dotnet ef database drop\` deletes the database"

  [[ $cmd =~ DROP[[:space:]]+(TABLE|DATABASE|SCHEMA|INDEX|VIEW|PROCEDURE|COLUMN) ]] && \
    add "DROP of a database object"

  [[ $cmd =~ TRUNCATE[[:space:]]+TABLE ]] && \
    add "TRUNCATE empties a table with no WHERE and no easy rollback"

  [[ $cmd =~ DELETE[[:space:]]+FROM ]] && [[ $cmd != *WHERE* && $cmd != *where* ]] && \
    add "DELETE FROM with no WHERE deletes every row"

  [[ $cmd =~ UPDATE[[:space:]] ]] && [[ $cmd =~ [[:space:]]SET[[:space:]] ]] && \
    [[ $cmd != *WHERE* && $cmd != *where* ]] && \
    add "UPDATE ... SET with no WHERE rewrites every row"

  [[ $cmd =~ ALTER[[:space:]]+TABLE ]] && [[ $cmd =~ DROP ]] && \
    add "ALTER TABLE ... DROP removes a column or constraint"
fi

(( ${#reasons[@]} == 0 )) && exit 0

# ---- emit the ask decision --------------------------------------------------
# Build a JSON string by hand; escape backslash, quote, then newline.
msg="SkyOps guard - destructive or irreversible operation detected:"
for r in "${reasons[@]}"; do msg+=$'\n'"  - $r"; done
msg+=$'\n'"If this is intentional, confirm. Safer options: --force-with-lease instead of --force;"
msg+=$'\n'"a feature branch instead of dev/main; git stash instead of reset --hard;"
msg+=$'\n'"a specific WHERE (id/tenant/date) or a scoped .sql migration instead of a bare DML."

esc=${msg//\\/\\\\}
esc=${esc//\"/\\\"}
esc=${esc//$'\n'/\\n}

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}' "$esc"
exit 0
