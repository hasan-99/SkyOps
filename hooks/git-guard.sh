#!/usr/bin/env bash
# SkyOps PreToolUse guard — dangerous git. Bash port of git-guard.js.
#
# Behaviour is intentionally identical to the Node original:
#   * flags history-rewriting / work-destroying git operations and pushes to a
#     protected branch, and asks for confirmation.
#   * decision is "ask" — surfaces + confirms, never hard-blocks.
#     --force-with-lease, pushing a feature branch, and normal git are left alone.
#   * any error => allow (exit 0). The guard must never block work on its own bug.
#
# Why bash: node.exe costs ~18-23s to start on this machine (Defender ATP scans
# every spawn), which blew this hook's 10s timeout — the guard was killed before
# it could decide, i.e. it was silently NOT guarding. bash starts in ~1.8s.
# No safety rule was changed or removed in the port.
#
# Helpers are inlined on purpose: a shared library that went missing would make
# every guard fail open and silently stop guarding, which is the exact bug this
# port exists to fix.

# --- JSON string reader (see sql-guard.sh for rationale) ----------------------
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

emit_ask() {
  json_escape "$1"
  printf '%s' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"ask\",\"permissionDecisionReason\":\"$JE\"}}"
}

# Decide on one hook payload. Sets GIT_REASON to the ask reason, or '' to allow.
# Always returns 0, never exits and never forks, so guard-dispatch.sh can source
# this file and call it in-process instead of paying a second ~0.75s spawn.
git_guard_decide() {
  RAW=$1
  GIT_REASON=''

TI=${RAW#*\"tool_input\"}
[ "$TI" = "$RAW" ] && TI=''
json_str "$TI" "command" || return 0
CMD=$R

WL='(^|[^[:alnum:]_])'
WR='([^[:alnum:]_]|$)'
S='[[:space:]]'
NL=$'\n'
NN="[^${NL}]"

# The original's first gate is case-SENSITIVE /\bgit\b/ — `GIT push` is not
# guarded there either, so this stays case-sensitive deliberately.
P_GIT="${WL}git${WR}"
[[ $CMD =~ $P_GIT ]] || return 0

# Split into lines: the original scopes most checks with [^\n]*, so a dangerous
# token on line 2 must not be attributed to a `git push` on line 1.
LINES=()
_tmp=$CMD
while [ -n "$_tmp" ]; do
  if [[ $_tmp == *"$NL"* ]]; then
    LINES+=("${_tmp%%"$NL"*}")
    _tmp=${_tmp#*"$NL"}
  else
    LINES+=("$_tmp"); break
  fi
done

# Remainder of the line following `git <verb>`, including the boundary char.
# JS's \b is zero-width, so the character that terminates the verb is still
# available to the following pattern — capturing it here preserves that
# (without it, `git push -f` would lose the space that \s-f\b needs).
mk_rest_pat() { REST_PAT="${WL}git${S}+$1"'([^[:alnum:]_]'"${NN}"'*|$)'; }

# $1 verb pattern, $2 pattern to find in the remainder, $3 = lc|cs
rest_has() {
  local verb=$1 want=$2 mode=$3 l t
  mk_rest_pat "$verb"
  for l in "${LINES[@]}"; do
    if [ "$mode" = lc ]; then t=${l,,}; else t=$l; fi
    if [[ $t =~ $REST_PAT ]] && [[ ${BASH_REMATCH[2]} =~ $want ]]; then return 0; fi
  done
  return 1
}

reasons=()

# 1. Force push (but not the safer --force-with-lease).
#    JS uses a negative lookahead, which ERE lacks; scrubbing the safe form out
#    of a lowercased copy first is exactly equivalent, including the case where
#    both --force and --force-with-lease appear on the same line.
mk_rest_pat 'push'
for _l in "${LINES[@]}"; do
  _t=${_l,,}
  _t=${_t//--force-with-lease/--xwl}
  if [[ $_t =~ $REST_PAT ]]; then
    _rest=${BASH_REMATCH[2]}
    if [[ $_rest =~ --force([^[:alnum:]_]|$) ]] || [[ $_rest =~ [[:space:]]-f([^[:alnum:]_]|$) ]]; then
      reasons+=('force push overwrites remote history'); break
    fi
  fi
done

# 2. Push straight to a protected branch.
rest_has 'push' "${WL}(main|master)${WR}" lc \
  && reasons+=('pushing directly to main/master (prefer a feature branch + review)')

# 3. Hard reset discards committed + working changes.
rest_has 'reset' '--hard([^[:alnum:]_]|$)' lc \
  && reasons+=('git reset --hard discards uncommitted work')

# 4. Force clean removes untracked files/dirs.
rest_has 'clean' '\-[a-z]*f' lc \
  && reasons+=('git clean -f deletes untracked files')

# 5. Force-delete a branch (case-sensitive: -D must not match -d).
rest_has 'branch' '[[:space:]]\-D([^[:alnum:]_]|$)' cs \
  && reasons+=('git branch -D force-deletes a branch (may lose unmerged commits)')

# 6. Discard working-tree changes via checkout. No [^\n]* in the original, and
#    \s matches newlines in JS, so this runs against the whole command.
P_CO="${WL}git${S}+checkout${S}+(--${S}+[.]|[.])([[:space:]]|$)"
[[ $CMD =~ $P_CO ]] && reasons+=('git checkout . discards local changes')

# 7. git restore, unless --staged appears later on the same line.
mk_rest_pat 'restore'
for _l in "${LINES[@]}"; do
  if [[ $_l =~ $REST_PAT ]]; then
    _rest=${BASH_REMATCH[2]}
    [[ $_rest == *"--staged"* ]] && continue
    if [[ $_rest =~ ([.]|[[:space:]]--[[:space:]]) ]]; then
      reasons+=('git restore discards working-tree changes'); break
    fi
  fi
done

# 8. History rewriting (whole command; no [^\n]* in the original).
P_FILTER="${WL}git${S}+(filter-branch|filter-repo)${WR}"
[[ $CMD =~ $P_FILTER ]] && reasons+=('history rewrite across the repo')

# 9. Deleting a remote branch/ref.
rest_has 'push' '--delete([^[:alnum:]_]|$)' lc \
  && reasons+=('deleting a remote branch/ref')

[ ${#reasons[@]} -eq 0 ] && return 0

joined=''
for r in "${reasons[@]}"; do
  if [ -z "$joined" ]; then joined=$r; else joined="$joined"$'\n'"  - $r"; fi
done

GIT_REASON="SkyOps git guard — destructive/irreversible git op detected:
  - ${joined}
If this is intentional, confirm. Safer options: --force-with-lease instead of --force, a feature branch instead of pushing to main, \`git stash\` instead of reset --hard."
}

# --- standalone -------------------------------------------------------------
# Unchanged wire behaviour when this file is executed directly.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  RAW=''
  if [ ! -t 0 ]; then IFS= read -r -d '' RAW; fi
  git_guard_decide "$RAW"
  [ -n "$GIT_REASON" ] && emit_ask "$GIT_REASON"
  exit 0
fi
