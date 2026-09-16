#!/usr/bin/env bash
# SkyOps token telemetry. Reads what the sessions actually cost.
#
# Why this exists: SkyOps' stated purpose is token discipline, and until now nothing
# measured tokens. `stats-cache.json` counts messages and tool calls, not tokens.
# The real numbers live in the session transcripts, where every assistant message
# carries a usage record.
#
# The four numbers that matter, and why they are not interchangeable:
#
#   input               tokens billed at full input price (the uncached part)
#   cache_creation      tokens written into the cache - billed ABOVE input price
#   cache_read          tokens served from cache - billed well BELOW input price
#   output              generated tokens, the most expensive per unit
#
# A healthy long session is mostly cache_read. A high cache_creation share means the
# prompt prefix keeps changing - prompt caching is a PREFIX match, so any byte that
# moves invalidates everything after it and forces a rewrite.
#
# Usage:
#   skyops-tokens.sh                 all sessions, summary
#   skyops-tokens.sh --top 10        the 10 most expensive sessions
#   skyops-tokens.sh --since 2026-09-01
#   skyops-tokens.sh --session <id>  one session

set -u

TOP=0
SINCE=''
ONE=''
ROOT="${USERPROFILE:-$HOME}/.claude/projects"
[[ -d $ROOT ]] || ROOT="/c/Users/$USER/.claude/projects"

while (( $# )); do
  case $1 in
    --top)     TOP=${2:-10}; shift 2 ;;
    --since)   SINCE=${2:-}; shift 2 ;;
    --session) ONE=${2:-}; shift 2 ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

[[ -d $ROOT ]] || { echo "No projects folder at $ROOT" >&2; exit 1; }

# One awk pass over every transcript. Extracting with awk's match() rather than a
# grep-per-file loop: a fork per file costs ~0.5s here, and there are ~100 files.
find "$ROOT" -name '*.jsonl' -type f 2>/dev/null | awk -v top="$TOP" -v since="$SINCE" -v one="$ONE" '
function num(line, key,   m, s) {
  if (match(line, "\"" key "\":[0-9]+")) {
    s = substr(line, RSTART, RLENGTH)
    sub(/^[^:]*:/, "", s)
    return s + 0
  }
  return 0
}
{ files[NR] = $0 }
END {
  for (i = 1; i <= NR; i++) {
    f = files[i]
    n = split(f, parts, /[\/\\]/)
    sid = parts[n]; sub(/\.jsonl$/, "", sid)
    if (one != "" && sid !~ one) continue

    inp = 0; cc = 0; cr = 0; out = 0; think = 0; msgs = 0; first = ""
    while ((getline line < f) > 0) {
      if (line !~ /"usage"/) {
        if (first == "" && match(line, /"timestamp":"[0-9-]{10}/))
          first = substr(line, RSTART+13, 10)
        continue
      }
      if (first == "" && match(line, /"timestamp":"[0-9-]{10}/))
        first = substr(line, RSTART+13, 10)
      inp   += num(line, "input_tokens")
      cc    += num(line, "cache_creation_input_tokens")
      cr    += num(line, "cache_read_input_tokens")
      out   += num(line, "output_tokens")
      think += num(line, "thinking_tokens")
      msgs++
    }
    close(f)
    if (msgs == 0) continue
    if (since != "" && first != "" && first < since) continue

    tot = inp + cc + cr + out
    sessions++
    T_in += inp; T_cc += cc; T_cr += cr; T_out += out; T_think += think; T_msgs += msgs
    sname[sessions] = substr(sid, 1, 8); sdate[sessions] = first
    stot[sessions] = tot; sout[sessions] = out; scr[sessions] = cr; scc[sessions] = cc
  }

  if (sessions == 0) { print "No sessions matched."; exit }

  T_all = T_in + T_cc + T_cr + T_out
  printf "\n  SkyOps token report - %d sessions, %d assistant messages\n\n", sessions, T_msgs
  printf "  %-22s %14s  %6s\n", "bucket", "tokens", "share"
  printf "  %-22s %14s  %6s\n", "----------------------", "--------------", "------"
  printf "  %-22s %14d  %5.1f%%\n", "input (full price)",  T_in,  100*T_in/T_all
  printf "  %-22s %14d  %5.1f%%\n", "cache write",         T_cc,  100*T_cc/T_all
  printf "  %-22s %14d  %5.1f%%\n", "cache read (cheap)",  T_cr,  100*T_cr/T_all
  printf "  %-22s %14d  %5.1f%%\n", "output",              T_out, 100*T_out/T_all
  printf "  %-22s %14d\n",          "  of which thinking", T_think
  printf "  %-22s %14d\n\n",        "TOTAL",               T_all

  reuse = (T_cc > 0) ? T_cr / T_cc : 0
  printf "  Cache reuse ratio      %.1fx   (cache_read / cache_write)\n", reuse
  printf "  Avg per session        %d tokens\n", T_all/sessions
  printf "  Avg output per session %d tokens\n\n", T_out/sessions

  if (reuse < 3) {
    print "  ! Low reuse. The prompt prefix is changing often - caching is a PREFIX"
    print "    match, so a rewritten CLAUDE.md/MEMORY.md or a shifting tool list"
    print "    invalidates everything after it. Check what rewrites mid-session."
  } else {
    print "  Cache is working: most context is being re-read cheaply, not re-billed."
  }

  if (top > 0) {
    printf "\n  Top %d sessions by total tokens\n\n", top
    printf "  %-10s %-12s %12s %12s %10s\n", "session", "date", "total", "cache_read", "output"
    for (a = 1; a <= sessions; a++)
      for (b = a+1; b <= sessions; b++)
        if (stot[b] > stot[a]) {
          for (k in tmp) delete tmp[k]
          t=stot[a]; stot[a]=stot[b]; stot[b]=t
          t=sname[a]; sname[a]=sname[b]; sname[b]=t
          t=sdate[a]; sdate[a]=sdate[b]; sdate[b]=t
          t=sout[a];  sout[a]=sout[b];   sout[b]=t
          t=scr[a];   scr[a]=scr[b];     scr[b]=t
        }
    n = (top < sessions) ? top : sessions
    for (a = 1; a <= n; a++)
      printf "  %-10s %-12s %12d %12d %10d\n", sname[a], sdate[a], stot[a], scr[a], sout[a]
  }
  print ""
}
'
