#!/usr/bin/env bash
# SkyOps statusline. Bash port of statusline.js.
# node.exe costs ~9s to start under Defender ATP and the JS version spawned
# 4 separate git processes on top of that (~65s per render, past every
# timeout). This keeps the same output but uses builtins plus one git call.

RAW=""
if [ ! -t 0 ]; then RAW=$(cat); fi

# --- JSON field readers (bash regex, no jq / no subprocess) ---
json_str() {
  local k=$1
  [[ $RAW =~ \"$k\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] || return 1
  local v=${BASH_REMATCH[1]}
  printf '%s' "${v//\\\\/\\}"
}
json_num() {
  local k=$1
  [[ $RAW =~ \"$k\"[[:space:]]*:[[:space:]]*([0-9]+(\.[0-9]+)?) ]] || return 1
  printf '%s' "${BASH_REMATCH[1]}"
}

# --- Colors ---
SKY=$'\033[38;2;125;211;252m'
TEAL=$'\033[38;2;20;184;166m'
ORANGE=$'\033[38;2;251;146;60m'
YELLOW=$'\033[38;2;234;179;8m'
DIM=$'\033[38;2;82;82;91m'
RST=$'\033[0m'
BOLD=$'\033[1m'
SEP="  ${DIM}||${RST}  "

# --- Directory ---
cwd=$(json_str current_dir) || cwd=""
[ -z "$cwd" ] && cwd=$(json_str cwd)
[ -z "$cwd" ] && cwd=$PWD
cwd=${cwd//\\//}
cwd=${cwd%/}

# --- Git: locate the repo root with builtins, then one status call ---
# A bare `.git` directory with no HEAD is a stray artifact, not a repo, so
# require HEAD (or a .git file, which is how worktrees/submodules link out).
root=""
d=$cwd
while [ -n "$d" ] && [ "$d" != "/" ] && [ "${d: -1}" != ":" ]; do
  if [ -f "$d/.git" ] || [ -f "$d/.git/HEAD" ]; then root=$d; break; fi
  [[ $d != */* ]] && break
  d=${d%/*}
done

branch=""; dirty=0; gitstate="unknown"
if [ -n "$root" ]; then
  while IFS= read -r line; do
    case $line in
      "# branch.head "*) branch=${line#\# branch.head } ;;
      \#*) ;;
      "") ;;
      *) dirty=$((dirty + 1)) ;;
    esac
  done < <(git -C "$root" status --porcelain=v2 --branch 2>/dev/null)
  [ -z "$branch" ] || [ "$branch" = "(detached)" ] && branch=${branch:-HEAD}
  if [ "$dirty" -gt 0 ]; then gitstate="changed"; else gitstate="clean"; fi
fi

repo=${root##*/}
[ -z "$repo" ] && repo=${cwd##*/}

# Display path: relative to SharedProjects when we are under it.
shortdir=$cwd
case $cwd in
  */SharedProjects/*) shortdir=${cwd#*/SharedProjects/} ;;
  */SharedProjects)   shortdir=$repo ;;
esac
[ -z "$shortdir" ] && shortdir=$repo

# --- Model ---
model=$(json_str display_name) || model=""
[ -z "$model" ] && model=$(json_str id)
[ -z "$model" ] && model="claude"
model=${model#claude-}
model=${model%-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]}

# --- Context ---
# Read the context numbers ONLY from the context_window object. The payload
# also carries rate_limits.five_hour.used_percentage (the 5h quota, which does
# NOT reset with the conversation), and a flat search matched that one whenever
# context_window was absent - which is the case on the render right after
# /clear. That is how a freshly cleared session kept showing 85%.
# No context_window means nothing used yet, so 0 is the honest answer.
ctx=""
if [[ $RAW =~ \"context_window\"[[:space:]]*:[[:space:]]*\{([^{}]*(\{[^{}]*\})?[^{}]*)\} ]]; then
  ctx=${BASH_REMATCH[0]}
fi

ctxmax=200000
pct=0
if [ -n "$ctx" ]; then
  [[ $ctx =~ \"context_window_size\"[[:space:]]*:[[:space:]]*([0-9]+) ]] && ctxmax=${BASH_REMATCH[1]}
  if [[ $ctx =~ \"used_percentage\"[[:space:]]*:[[:space:]]*([0-9]+(\.[0-9]+)?) ]]; then
    pct=${BASH_REMATCH[1]}
  elif [[ $ctx =~ \"total_input_tokens\"[[:space:]]*:[[:space:]]*([0-9]+) ]]; then
    pct=$(( ctxmax > 0 ? BASH_REMATCH[1] * 100 / ctxmax : 0 ))
  fi
fi
pct=${pct%%.*}
[ -z "$pct" ] && pct=0
[ "$pct" -gt 100 ] && pct=100

BAR=18
filled=$(( pct * BAR / 100 ))
bar=""
for ((i = 0; i < BAR; i++)); do
  if [ "$i" -lt "$filled" ]; then bar+="▰"; else bar+="▱"; fi
done
if   [ "$pct" -gt 75 ]; then barcolor=$ORANGE
elif [ "$pct" -gt 40 ]; then barcolor=$YELLOW
else                        barcolor=$TEAL
fi

# --- Cost ---
cost=""
if c=$(json_num total_cost_usd); then
  whole=${c%%.*}
  frac=${c#*.}
  [ "$frac" = "$c" ] && frac=0
  frac=${frac}000
  cents=$(( 10#${whole:-0} * 100 + 10#${frac:0:2} ))
  [ "10#${frac:2:1}" ] && [ "$((10#${frac:2:1}))" -ge 5 ] && cents=$((cents + 1))
  cost=$(printf '$%d.%02d' $((cents / 100)) $((cents % 100)))
fi

# --- Session time ---
# cost.total_duration_ms is this session's wall clock and is refreshed on every
# render, so no date parsing and no extra process are needed.
elapsed=""
if ms=$(json_num total_duration_ms); then
  ms=${ms%%.*}
  secs=$((ms / 1000))
  if [ "$secs" -ge 3600 ]; then
    elapsed=$(printf '%dh %02dm' $((secs / 3600)) $(((secs % 3600) / 60)))
  else
    elapsed=$(printf '%dm %02ds' $((secs / 60)) $((secs % 60)))
  fi
fi

# --- Framework: walk up 4 levels, no subprocesses ---
framework=""
d=$cwd
for _ in 1 2 3 4; do
  for f in "$d"/*.csproj; do
    [ -e "$f" ] || continue
    xml=$(<"$f")
    if [[ $xml =~ \<TargetFrameworks?\>([^\<]*)\< ]]; then
      fw=${BASH_REMATCH[1]%%;*}
      fw=${fw//[[:space:]]/}
      if   [[ $fw =~ ^net([0-9]+)\.[0-9]+$ ]];  then framework=".NET ${BASH_REMATCH[1]}"
      elif [[ $fw =~ ^netstandard([0-9.]+)$ ]]; then framework=".NET Std ${BASH_REMATCH[1]}"
      else framework=".NET"; fi
    else
      framework=".NET"
    fi
    break 2
  done
  for f in "$d"/*.sln;      do [ -e "$f" ] && { framework=".NET";   break 2; }; done
  [ -f "$d/package.json" ]     && { framework="Node.js"; break; }
  [ -f "$d/pyproject.toml" ] || [ -f "$d/requirements.txt" ] && { framework="Python"; break; }
  [[ $d != */* ]] && break
  d=${d%/*}
  [ -z "$d" ] && break
done

# --- Memory count ---
# $HOME points at a mapped drive under the bash Claude Code spawns, so try
# USERPROFILE too. The project key is the cwd with : and / turned into -.
projkey=${cwd//:/-}
projkey=${projkey//\//-}
memdir=""
for h in "$HOME" "${USERPROFILE//\\//}" "$HOMEDRIVE$HOMEPATH"; do
  [ -n "$h" ] || continue
  if [ -d "${h%/}/.claude/projects/$projkey/memory" ]; then
    memdir="${h%/}/.claude/projects/$projkey/memory"
    break
  fi
done
memcount=0
if [ -n "$memdir" ]; then
  for f in "$memdir"/*.md; do
    [ -e "$f" ] || continue
    [ "${f##*/}" = "MEMORY.md" ] && continue   # index, not a memory
    memcount=$((memcount + 1))
  done
fi

user=${USERNAME:-${USER:-user}}

printf '\n'
printf '%s SkyOps %s  %s||%s  %s★ Odyssey Member:%s %s%s%s%s%s%s%s\n' \
  "$SKY$BOLD" "$RST" "$DIM" "$RST" "$SKY" "$RST" "$SKY" "$user" "$RST" \
  "$SEP" "$TEAL" "$shortdir" "$RST"

line2="  ${SKY}${model}${RST}  ${barcolor}${bar}${RST}  ${SKY}${pct}% session${RST}"
[ -n "$elapsed" ]   && line2+="${SEP}${DIM}time ${RST}${SKY}${elapsed}${RST}"
[ -n "$cost" ]      && line2+="${SEP}${ORANGE}${cost}${RST}"
[ -n "$framework" ] && line2+="${SEP}${SKY}${framework}${RST}"
line2+="${SEP}${DIM}mem ${RST}${SKY}${memcount}${RST}"
printf '%s\n' "$line2"

if [ -n "$branch" ]; then
  if [ "$dirty" -gt 0 ]; then
    printf '  %s●%s %s%s%s  %s~%d changed%s\n' "$DIM" "$RST" "$SKY" "$branch" "$RST" "$ORANGE" "$dirty" "$RST"
  else
    printf '  %s●%s %s%s%s  %snothing to commit%s\n' "$DIM" "$RST" "$SKY" "$branch" "$RST" "$SKY" "$RST"
  fi
fi

printf '\n'
