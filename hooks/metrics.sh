#!/usr/bin/env bash
# SkyOps metrics — bash port of metrics.js. Sourced, never executed.
#
# OFF BY DEFAULT: nothing is written unless SKYOPS_METRICS=1.
#
# Fork-free on purpose. A fork costs ~0.29-0.43s on this machine (measured), so
# `date`, `cat` and $( ) are all banned here — the recorder would otherwise cost
# more than the hook it measures. Timestamps come from $EPOCHREALTIME and
# printf's builtin %(..)T, appends use a builtin redirect.
#
# Records sizes, counts, durations and short identifiers only. Never prompt
# text, source, tool results or command strings — same contract as metrics.js.
#
# skyops_metric_start            -> stamps the start time
# skyops_metric "k=v" "k=v" ...  -> appends one JSON line
#
# Values are emitted as numbers when they look numeric, otherwise as strings,
# and any value that is not a short safe identifier is dropped.

SKYOPS_T0=''

skyops_metric_start() {
  [ "${SKYOPS_METRICS:-}" = "1" ] || return 0
  SKYOPS_T0=${EPOCHREALTIME/./}   # microseconds, no fork
}

# Milliseconds since skyops_metric_start, into SKYOPS_MS.
skyops_metric_ms() {
  SKYOPS_MS=0
  [ -n "$SKYOPS_T0" ] || return 0
  local now=${EPOCHREALTIME/./}
  SKYOPS_MS=$(( (now - SKYOPS_T0) / 1000 ))
}

skyops_metric() {
  [ "${SKYOPS_METRICS:-}" = "1" ] || return 0

  local dir=${SKYOPS_METRICS_DIR:-$HOME/.claude/skyops-metrics}
  [ -d "$dir" ] || mkdir -p "$dir" 2>/dev/null || return 0

  local day; printf -v day '%(%Y-%m-%d)T' -1          # builtin, no fork
  local ts;  printf -v ts  '%(%Y-%m-%dT%H:%M:%S)T' -1

  local line='{"ts":"'$ts'"' kv k v
  for kv in "$@"; do
    k=${kv%%=*}
    v=${kv#*=}
    # Keys must be plain identifiers.
    case $k in
      *[!A-Za-z0-9_]*|'') continue ;;
    esac
    if [[ $v =~ ^-?[0-9]+$ ]]; then
      line="$line,\"$k\":$v"                           # number
    elif [ "$v" = true ] || [ "$v" = false ]; then
      line="$line,\"$k\":$v"                           # boolean
    else
      # Same whitelist as metrics.js: a short identifier, never a payload.
      case $v in
        *[!A-Za-z0-9_.:-]*|'') continue ;;
      esac
      [ ${#v} -gt 64 ] && continue
      line="$line,\"$k\":\"$v\""
    fi
  done
  line="$line}"

  printf '%s\n' "$line" >> "$dir/$day.jsonl" 2>/dev/null || true
}
