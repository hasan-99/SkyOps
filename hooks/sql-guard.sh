#!/usr/bin/env bash
# SkyOps PreToolUse guard — destructive SQL. Bash port of sql-guard.js.
#
# Behaviour is intentionally identical to the Node original:
#   * only reacts when the command actually EXECUTES SQL through a known runner
#     (sqlcmd/psql/mysql/sqlite3/dotnet ef ...) AND that SQL is destructive.
#     Reading/grepping a .sql file is never flagged.
#   * decision is "ask" — surfaces the danger and lets the user confirm; it does
#     not hard-block, so a legitimate intentional op is one confirmation away.
#   * any parsing error => allow (exit 0). A hook bug must never block work.
#
# Why bash: node.exe costs ~18s to start on this machine (Defender ATP scans
# every spawn), which blew this hook's 10s timeout — the guard was killed before
# it could decide, i.e. it was silently NOT guarding. bash starts in ~1.8s.
# No safety rule was changed or removed in the port.
#
# Helpers are inlined on purpose: a shared library that went missing would make
# every guard fail open and silently stop guarding, which is the exact bug this
# port exists to fix.

# --- JSON string reader -------------------------------------------------------
# Decodes a JSON string value by key, honouring backslash escapes, so a command
# containing \" or \\ is read in full rather than truncated at the first escape.
# Returns through the global R (never by printing: $( ) forks, and a fork costs
# ~0.5s on this machine).
R=''
json_str() {
  local hay=$1 key=$2 rest c span tmp
  local Q='"' BS='\' B2='\\' EQ='\"' EN='\n' ET='\t' ER='\r' EB='\b' EF='\f' ESL='\/' SL='/'
  local S1=$'\001' S2=$'\002'
  rest=${hay#*\"$key\"}
  [ "$rest" = "$hay" ] && { R=''; return 1; }
  while [ -n "$rest" ]; do
    c=${rest:0:1}
    case $c in
      ' '|$'\t'|$'\n'|$'\r'|':') rest=${rest:1} ;;
      '"') rest=${rest:1}; break ;;
      *) R=''; return 1 ;;   # value is not a string (null/number/object)
    esac
  done
  # Fast path: nothing escaped before the closing quote, so take it in one op.
  span=${rest%%"$Q"*}
  [ "$span" = "$rest" ] && { R=''; return 1; }   # unterminated string
  if [[ $span != *"$BS"* ]]; then R=$span; return 0; fi
  # Escaped content. Neutralise \\ and \" first so the next bare quote is the
  # true terminator, then decode with bulk substitutions.
  #
  # Both earlier versions risked this hook's timeout, which is the exact bug the
  # port exists to fix: walking character-by-character was O(n^2) and took 28s
  # on a 32KB command; jumping backslash-to-backslash was O(k*n) and took 7.7s
  # on a path list holding 1600 backslashes. These substitutions are O(n).
  tmp=${rest//"$B2"/$S1}
  tmp=${tmp//"$EQ"/$S2}
  span=${tmp%%"$Q"*}
  [ "$span" = "$tmp" ] && { R=''; return 1; }
  span=${span//"$EN"/$'\n'}
  span=${span//"$ET"/$'\t'}
  span=${span//"$ER"/$'\r'}
  span=${span//"$EB"/$'\b'}
  span=${span//"$EF"/$'\f'}
  span=${span//"$ESL"/"$SL"}
  if [[ $span == *'\u'* ]]; then
    local out='' pre h
    while [[ $span == *'\u'* ]]; do
      pre=${span%%'\u'*}
      out+=$pre
      span=${span#*'\u'}
      h=${span:0:4}
      if [[ $h =~ ^[0-9a-fA-F]{4}$ ]]; then
        span=${span:4}; printf -v c "\\u$h"; out+=$c
      else
        out+='\u'
      fi
    done
    span=$out$span
  fi
  span=${span//$S2/$Q}
  span=${span//$S1/$BS}
  R=$span; return 0
}

# --- JSON string escaper ------------------------------------------------------
JE=''
json_escape() {
  local s=$1 out='' c i n=${#1}
  for (( i=0; i<n; i++ )); do
    c=${s:i:1}
    case $c in
      '"') out+='\"' ;;
      \\) out+='\\' ;;
      $'\n') out+='\n' ;;
      $'\r') out+='\r' ;;
      $'\t') out+='\t' ;;
      $'\b') out+='\b' ;;
      $'\f') out+='\f' ;;
      *) out+=$c ;;
    esac
  done
  JE=$out
}

allow() { exit 0; }

ask() {
  json_escape "$1"
  printf '%s' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"ask\",\"permissionDecisionReason\":\"$JE\"}}"
  exit 0
}

# --- read stdin (no fork; $(cat) would cost ~0.5s) ----------------------------
RAW=''
if [ ! -t 0 ]; then IFS= read -r -d '' RAW; fi

# Scope to tool_input, mirroring `data.tool_input && data.tool_input.command`.
TI=${RAW#*\"tool_input\"}
[ "$TI" = "$RAW" ] && TI=''
json_str "$TI" "command" || allow
CMD=$R
[ -z "${CMD//[[:space:]]/}" ] && allow    # JS: !cmd.trim()

# All SQL checks below are case-insensitive in the original (/i). Rather than
# rely on nocasematch (which does not cover ${var//pat/}), match lowercase
# patterns against a lowercased copy — same result, fully predictable.
LC=${CMD,,}

# ERE has no \b, so word boundaries are spelled out. WR consumes a character,
# whereas JS's \b is zero-width; where a boundary is immediately followed by
# more pattern, the boundary character is captured into the remainder instead
# (see P_UPD / P_ALT) so that e.g. "UPDATE SET" still matches as it does in JS.
WL='(^|[^[:alnum:]_])'
WR='([^[:alnum:]_]|$)'
S='[[:space:]]'

P_RUNNER="${WL}(sqlcmd|osql|invoke-sqlcmd|psql|mysql|mariadb|sqlite3)${WR}"
P_EFDB="${WL}dotnet${S}+ef${S}+database${S}+(drop|update)${WR}"

# Only guard actual SQL execution. If no SQL runner is invoked, we can't claim
# it's destructive (it might just be reading a migration file).
if ! [[ $LC =~ $P_RUNNER ]] && ! [[ $LC =~ $P_EFDB ]]; then allow; fi

P_EFDROP="${WL}dotnet${S}+ef${S}+database${S}+drop${WR}"
P_DROP="${WL}drop${S}+(table|database|schema|index|view|procedure|column)${WR}"
P_TRUNC="${WL}truncate${S}+table${WR}"
P_DELFROM="${WL}delete${S}+from${WR}"
P_WHERE="${WL}where${WR}"
P_UPD="${WL}update([^[:alnum:]_].*|$)"
P_SET="${WL}set${WR}"
P_ALT="${WL}alter${S}+table([^[:alnum:]_].*|$)"
P_DROPW="${WL}drop${WR}"

reasons=()

[[ $LC =~ $P_EFDROP ]] && reasons+=('`dotnet ef database drop` deletes the database')
[[ $LC =~ $P_DROP ]]   && reasons+=('DROP of a database object')
[[ $LC =~ $P_TRUNC ]]  && reasons+=('TRUNCATE empties a table with no WHERE and no easy rollback')
[[ $LC =~ $P_DELFROM ]] && ! [[ $LC =~ $P_WHERE ]] && reasons+=('DELETE FROM with no WHERE deletes every row')

if [[ $LC =~ $P_UPD ]]; then
  _rest=${BASH_REMATCH[2]}
  if [[ $_rest =~ $P_SET ]] && ! [[ $LC =~ $P_WHERE ]]; then
    reasons+=('UPDATE ... SET with no WHERE rewrites every row')
  fi
fi

if [[ $LC =~ $P_ALT ]]; then
  _rest=${BASH_REMATCH[2]}
  [[ $_rest =~ $P_DROPW ]] && reasons+=('ALTER TABLE ... DROP removes a column/constraint')
fi

[ ${#reasons[@]} -eq 0 ] && allow   # SQL runs, but it's not destructive.

joined=''
for r in "${reasons[@]}"; do
  if [ -z "$joined" ]; then joined=$r; else joined="$joined"$'\n'"  - $r"; fi
done

ask "SkyOps SQL guard — destructive operation detected:
  - ${joined}
Safe alternative: add a specific WHERE (id/tenant/date), prefer a soft delete, run SELECT COUNT(*) of the target rows first, or scope the migration. See /sky-sql-destructive-guard for the full check."
