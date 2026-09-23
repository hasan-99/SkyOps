#!/usr/bin/env bash
# SkyOps PostToolUse dispatcher (bash) — Edit/Write file events.
#
# One process per edit instead of one per hook. Wiring dotnet-format.sh next to
# the existing sky-test-nudge.sh entry would reintroduce the exact duplication
# guard-dispatch.sh was built to remove, just on the edit path — this sources
# both and calls them in-process instead.
#
# Sourcing, not sub-shelling: a fork costs ~0.3-0.75s on this machine (measured)
# against ~0s for a sourced call, so a dispatcher that forked its children would
# be slower than the two spawns it replaces.
#
# Behaviour preserved: never blocks, never fails an edit, exit code always 0.
# The two hooks emit different fields (systemMessage vs additionalContext), so
# both survive in one payload.

SKYOPS_SELF=${BASH_SOURCE[0]//\\//}
SKYOPS_DIR=${SKYOPS_SELF%/*}
[ "$SKYOPS_DIR" = "$SKYOPS_SELF" ] && SKYOPS_DIR=.

# shellcheck source=/dev/null
[ -r "$SKYOPS_DIR/metrics.sh" ] && . "$SKYOPS_DIR/metrics.sh"
type skyops_metric >/dev/null 2>&1 || { skyops_metric() { :; }; skyops_metric_start() { :; }; skyops_metric_ms() { SKYOPS_MS=0; }; }
skyops_metric_start

# Read stdin once (no fork). sky-test-nudge's original 2s timeout is kept here,
# since it is the tighter of the two and this now covers both hooks' read.
RAW=''
if [ ! -t 0 ]; then IFS= read -r -d '' -t 2 RAW; fi

DOTNET_FORMAT_MESSAGE=''
NUDGE_CONTEXT=''

if [ -r "$SKYOPS_DIR/dotnet-format.sh" ]; then
  # shellcheck source=/dev/null
  . "$SKYOPS_DIR/dotnet-format.sh" && dotnet_format_decide "$RAW"
fi

# sky-test-nudge was wired for Edit|Write only, never MultiEdit. This dispatcher
# is wired on the wider Edit|Write|MultiEdit (matching dotnet-format's original
# matcher), so gate the nudge on tool_name to keep it off MultiEdit exactly as
# before — mirrors nudgeApplies() in edit-dispatch.js. An absent/unknown
# tool_name still runs it, matching the old behaviour when the field is missing.
TOOL_NAME=''
json_str "$RAW" "tool_name" && TOOL_NAME=$R

if [ "$TOOL_NAME" != "MultiEdit" ] && [ -r "$SKYOPS_DIR/sky-test-nudge.sh" ]; then
  # shellcheck source=/dev/null
  . "$SKYOPS_DIR/sky-test-nudge.sh" && sky_test_nudge_decide "$RAW"
fi

skyops_metric_ms
EMITTED=0
[ -n "$DOTNET_FORMAT_MESSAGE" ] && EMITTED=$((EMITTED + ${#DOTNET_FORMAT_MESSAGE}))
[ -n "$NUDGE_CONTEXT" ] && EMITTED=$((EMITTED + ${#NUDGE_CONTEXT}))
skyops_metric kind=hook hook=edit-dispatch event=PostToolUse "ms=$SKYOPS_MS" impl=bash "emitted_bytes=$EMITTED"

[ -z "$DOTNET_FORMAT_MESSAGE" ] && [ -z "$NUDGE_CONTEXT" ] && exit 0

# Both fields can legitimately be present at once (a qualifying edit gets both
# the format reminder and the test nudge), so build the object field by field
# rather than picking one.
OUT="{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\""
if [ -n "$DOTNET_FORMAT_MESSAGE" ]; then
  json_escape "$DOTNET_FORMAT_MESSAGE"
  OUT="$OUT,\"systemMessage\":\"$JE\""
fi
if [ -n "$NUDGE_CONTEXT" ]; then
  json_escape "$NUDGE_CONTEXT"
  OUT="$OUT,\"additionalContext\":\"$JE\""
fi
OUT="$OUT}}"

printf '%s' "$OUT"
exit 0
