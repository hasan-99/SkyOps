#!/usr/bin/env bash
# PostToolUse (Edit|Write) nudge: after a C# SOURCE edit in CS_Datafactory_v2,
# remind the model to close the test loop with /sky-test diff.
# Emits nothing for anything else, so it is silent outside that repo's source.
# Bash port of sky-test-nudge.js — behaviour identical, including the
# never-break-the-pipeline rule (any error => exit 0, no output).
#
# Why bash: node.exe costs ~18s to start on this machine (Defender ATP scans
# every spawn), so this nudge added ~18s to every Edit/Write. bash starts ~1.8s.

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

# Decide on one hook payload. Sets NUDGE_CONTEXT to the additionalContext text,
# or '' when there is nothing to say. Always returns 0, never exits and never
# forks, so edit-dispatch.sh can source this file and call it in-process instead
# of paying a second ~0.75s spawn.
sky_test_nudge_decide() {
  RAW=$1
  NUDGE_CONTEXT=''
  [ -z "${RAW//[[:space:]]/}" ] && return 0

FP=''
TI=${RAW#*\"tool_input\"}
if [ "$TI" != "$RAW" ]; then json_str "$TI" "file_path" && FP=$R; fi
if [ -z "$FP" ]; then
  TR=${RAW#*\"tool_response\"}
  if [ "$TR" != "$RAW" ]; then json_str "$TR" "filePath" && FP=$R; fi
fi
[ -z "$FP" ] && return 0

SLASHED=${FP//\\//}
P=${SLASHED,,}

# Only this repo.
[[ $P == *"/cs_datafactory_v2/"* ]] || return 0
# Only C# source.
[[ $P == *".cs" ]] || return 0
# Skip the test tree itself (we're nudging about the source that changed).
[[ $P == *"/test/"* ]] && return 0
[[ $P == *".tests/"* ]] && return 0
# Skip generated / build / non-unit-tested artifacts.
[[ $P == *"/obj/"* || $P == *"/bin/"* ]] && return 0
[[ $P == *"/migrations/"* ]] && return 0
[[ $P == *".g.cs" || $P == *".designer.cs" ]] && return 0
[[ $P == *"/assemblyinfo.cs" || $P == *"assemblyattributes.cs" ]] && return 0

NAME=${SLASHED##*/}

NUDGE_CONTEXT="You just edited C# source in CS_Datafactory_v2 (${NAME}). Before treating this change as done, close the test loop with /sky-test diff: map the change to the tests that cover it, edit existing tests or create missing ones in the repo's xUnit + NSubstitute style (plain Assert, per-module CreateSut/InMemory-vs-mock convention), run only the affected tests, fix failures within budget, and commit per the run's commit mode (ask-first unless commit=auto). If this edit was itself a test file or has no runtime surface, ignore this."
}

# --- standalone -------------------------------------------------------------
# Unchanged wire behaviour when this file is executed directly. Mirrors the
# Node 1500ms stdin fallback: never hang the tool pipeline waiting for input
# that is not coming. bash assigns partial input on timeout.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  RAW=''
  if [ ! -t 0 ]; then IFS= read -r -d '' -t 2 RAW; fi
  sky_test_nudge_decide "$RAW"
  if [ -n "$NUDGE_CONTEXT" ]; then
    json_escape "$NUDGE_CONTEXT"
    printf '%s' "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"$JE\"}}"
  fi
  exit 0
fi
