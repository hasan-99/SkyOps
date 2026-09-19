#!/usr/bin/env bash
# SkyOps UserPromptSubmit hook — deterministic lesson recall.
#
# Scores the user's prompt against the lesson store and injects only strong
# matches, so a saved lesson resurfaces without the model remembering to call
# /sky-recall.
#
# Why bash, not the .js: node.exe costs ~9.3s to start on this machine
# (Defender ATP scans every spawn) against ~1.2s for bash — measured, not
# assumed. This hook fires on EVERY prompt, so a node implementation would add
# ~9s to every turn. Same reason sky-test-nudge.sh exists. knowledge-recall.js
# keeps the --reindex/--stats side, which runs once per saved lesson.
#
# Hot path spawns nothing: it reads one pre-generated TSV with builtin reads.
# Regenerate that file with: node knowledge-recall.js --reindex
#
# index.rec is US-separated (0x1F), not tab-separated, on purpose. Tab is IFS
# whitespace, so `read` collapses a run of tabs into a single delimiter and an
# empty field — a lesson with no `srv`, which is allowed — would silently shift
# every field after it. A non-whitespace separator keeps empty fields.
#
# Any error => exit 0 with no output. A recall bug must never block or pollute
# a session.

STORE=${SKYOPS_KNOWLEDGE_DIR:-$HOME/.claude/skyops-knowledge}
[ -n "$USERPROFILE" ] && [ ! -d "$STORE" ] && STORE="${USERPROFILE//\\//}/.claude/skyops-knowledge"
IDX="$STORE/index.rec"
[ -s "$IDX" ] || exit 0

MIN_SCORE=2      # below this, stay silent — a weak match costs tokens forever
MAX_HITS=3       # never inject more than 3 lessons
MIN_PROMPT=12    # "yes", "go on" — nothing to match

# ---- JSON string extraction (same proven approach as sky-test-nudge.sh) ----
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
      *) R=''; return 1 ;;
    esac
  done
  span=${rest%%"$Q"*}
  [ "$span" = "$rest" ] && { R=''; return 1; }
  if [[ $span != *"$BS"* ]]; then R=$span; return 0; fi
  tmp=${rest//"$B2"/$S1}
  tmp=${tmp//"$EQ"/$S2}
  span=${tmp%%"$Q"*}
  [ "$span" = "$tmp" ] && { R=''; return 1; }
  span=${span//"$EN"/ }
  span=${span//"$ET"/ }
  span=${span//"$ER"/ }
  span=${span//"$EB"/ }
  span=${span//"$EF"/ }
  span=${span//"$ESL"/"$SL"}
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
      *) out+=$c ;;
    esac
  done
  JE=$out
}

RAW=''
if [ ! -t 0 ]; then IFS= read -r -d '' -t 2 RAW; fi
[ -z "${RAW//[[:space:]]/}" ] && exit 0

json_str "$RAW" "prompt" || exit 0
PROMPT=$R
[ ${#PROMPT} -lt $MIN_PROMPT ] && exit 0
case $PROMPT in /sky-recall*) exit 0 ;; esac   # don't double up

# Normalise: lowercase, collapse everything that isn't an identifier char to a
# space, and pad so " word " boundary tests work at both ends.
P=${PROMPT,,}
CLEAN=''
for (( i=0; i<${#P}; i++ )); do
  c=${P:i:1}
  case $c in
    [a-z0-9._/-]) CLEAN+=$c ;;
    *) CLEAN+=' ' ;;
  esac
done
P=" $CLEAN "

# ---- score every indexed lesson -------------------------------------------
declare -a B_ID B_SC B_TITLE B_SRV B_HITS B_FILES B_APPLY B_WHY
n=0
while IFS=$'\037' read -r id hits srv repo title triggers bases files apply; do
  [ -z "$id" ] && continue
  # A hand-edited or truncated index must not throw arithmetic errors.
  [[ $hits =~ ^[0-9]+$ ]] || hits=1
  s=0; why=''
  if [ -n "$triggers" ]; then
    IFS=',' read -ra TL <<< "$triggers"
    for t in "${TL[@]}"; do
      [ ${#t} -lt 3 ] && continue
      # Also try the spaced form: a trigger written `ignore-alert` must still
      # match a prompt that says "ignore alert", which is how people type it.
      t2=${t//-/ }
      if [[ $P == *" $t "* || $P == *"/$t"* || $P == *"$t."* \
         || ( $t2 != "$t" && $P == *" $t2 "* ) ]]; then
        # Specificity is confidence. A long trigger is a real identifier
        # (socalertsdtovalidator, createprojectscope) and is strong evidence on
        # its own; a short one (alerts, pill) could be incidental, so it needs
        # corroboration to clear MIN_SCORE.
        if [ ${#t} -ge 12 ]; then s=$(( s + 2 )); else s=$(( s + 1 )); fi
        why+="${why:+, }$t"
      fi
    done
  fi
  if [ -n "$srv" ] && [[ $P == *"$srv"* ]]; then s=$(( s + 3 )); why+="${why:+, }$srv"; fi
  if [ -n "$repo" ] && [[ $P == *"$repo"* ]]; then s=$(( s + 1 )); fi
  if [ -n "$bases" ]; then
    IFS=',' read -ra BL <<< "$bases"
    for b in "${BL[@]}"; do
      [ -z "$b" ] && continue
      if [[ $P == *"$b"* ]]; then s=$(( s + 2 )); why+="${why:+, }$b"; fi
    done
  fi
  [ "$s" -lt "$MIN_SCORE" ] && continue
  # Recurrence only ever breaks ties; it can never lift a lesson over MIN_SCORE.
  [ "${hits:-1}" -ge 3 ] && s=$(( s * 10 + 1 )) || s=$(( s * 10 ))
  B_ID[n]=$id; B_SC[n]=$s; B_TITLE[n]=$title; B_SRV[n]=$srv
  B_HITS[n]=$hits; B_FILES[n]=$files; B_APPLY[n]=$apply; B_WHY[n]=$why
  n=$(( n + 1 ))
done < "$IDX"

[ "$n" -eq 0 ] && exit 0

# Top-N by score without spawning sort.
OUT="SkyOps recall — saved lesson(s) matching this request. Treat as a prior"$'\n'
OUT+="observation to verify, not as current truth. Check the cited file before acting."$'\n\n'
shown=0
while [ "$shown" -lt "$MAX_HITS" ]; do
  best=-1; bestsc=-1
  for (( i=0; i<n; i++ )); do
    [ -z "${B_ID[i]}" ] && continue
    if [ "${B_SC[i]}" -gt "$bestsc" ]; then bestsc=${B_SC[i]}; best=$i; fi
  done
  [ "$best" -lt 0 ] && break
  srvtag=''; [ -n "${B_SRV[best]}" ] && srvtag=" [${B_SRV[best]^^}]"
  hittag=''; [ "${B_HITS[best]:-1}" -ge 2 ] && hittag=" (seen ${B_HITS[best]}x)"
  OUT+="- ${B_TITLE[best]}${srvtag}${hittag}"$'\n'
  [ -n "${B_FILES[best]}" ] && OUT+="  where: ${B_FILES[best]}"$'\n'
  [ -n "${B_APPLY[best]}" ] && OUT+="  ${B_APPLY[best]}"$'\n'
  OUT+="  matched: ${B_WHY[best]} | id: ${B_ID[best]}"$'\n'
  B_ID[best]=''
  shown=$(( shown + 1 ))
done

[ "$shown" -eq 0 ] && exit 0

json_escape "$OUT"
printf '%s' "{\"hookSpecificOutput\":{\"hookEventName\":\"UserPromptSubmit\",\"additionalContext\":\"$JE\"}}"
exit 0
