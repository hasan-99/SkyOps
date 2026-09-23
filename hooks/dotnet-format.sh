#!/usr/bin/env bash
# SkyOps PostToolUse — .NET formatting reminder. Bash port of dotnet-format.js.
#
# Behaviour is intentionally identical to the Node original:
#   * only acts on .cs files; silent for everything else.
#   * default is a reminder to run `dotnet format` + build before committing.
#   * SKYOPS_AUTOFORMAT=1 opts in to actually running `dotnet format` on the
#     changed file, scoped to the nearest .csproj, best-effort and time-boxed.
#   * NEVER blocks and never fails the edit — any error exits 0 silently.
#
# Why bash: on this machine a node spawn costs ~7.3s against ~0.75s for bash
# (measured). This hook fires on every edit, so the port is the difference
# between usable and intolerable.
#
# Note: the `dotnet format` path necessarily forks. That only happens when the
# user opts in, and it is dwarfed by dotnet's own startup.

# --- minimal JSON string reader (same approach as the guards, no fork) -------
R=''
json_str() {
  local hay=$1 key=$2 rest c span tmp
  local Q='"' BS='\' B2='\\' EQ='\"' EN='\n' ET='\t' ER='\r'
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
  span=${span//"$EN"/$'\n'}
  span=${span//"$ET"/$'\t'}
  span=${span//"$ER"/$'\r'}
  span=${span//"$S2"/\"}
  span=${span//"$S1"/\\}
  R=$span
  return 0
}

json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  JE=$s
}

emit_message() {
  json_escape "$1"
  printf '%s' "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"systemMessage\":\"$JE\"}}"
}

# Decide on one hook payload. Sets DOTNET_FORMAT_MESSAGE, or '' when silent.
# Always returns 0, never exits and never forks (except the opt-in `dotnet
# format` itself), so edit-dispatch.sh can source this file and call it
# in-process instead of paying a second ~0.75s spawn.
dotnet_format_decide() {
  RAW=$1
  DOTNET_FORMAT_MESSAGE=''
  [ -z "$RAW" ] && return 0

  TI=${RAW#*\"tool_input\"}
  [ "$TI" = "$RAW" ] && TI=''
  FILE=''
  json_str "$TI" "file_path" && FILE=$R
  [ -z "$FILE" ] && { json_str "$TI" "path" && FILE=$R; }

  # Not C# -> silent. Mirrors /\.cs$/i.
  LCF=${FILE,,}
  case $LCF in
    *.cs) ;;
    *) return 0 ;;
  esac

  BASE=${FILE##*[/\\]}

  case ${SKYOPS_AUTOFORMAT:-} in
    1|true|yes|on|TRUE|YES|ON|True|Yes|On) ;;
    *)
      DOTNET_FORMAT_MESSAGE="SkyOps: edited $BASE. Before committing, run \`dotnet format\` and a \`dotnet build\` on the affected project. (Set SKYOPS_AUTOFORMAT=1 to auto-format changed .cs files.)"
      return 0 ;;
  esac

  # --- opt-in autoformat: find the nearest .csproj, walking up at most 12 levels
  local DIR PROJ c i
  DIR=${FILE%/*}
  DIR=${DIR//\\//}
  PROJ=''
  i=0
  while [ $i -lt 12 ] && [ -n "$DIR" ]; do
    for c in "$DIR"/*.csproj; do
      [ -e "$c" ] && { PROJ=$c; break; }
    done
    [ -n "$PROJ" ] && break
    case $DIR in
      */*) DIR=${DIR%/*} ;;
      *) break ;;
    esac
    i=$((i + 1))
  done

  if [ -z "$PROJ" ]; then
    DOTNET_FORMAT_MESSAGE="SkyOps: edited $BASE; no .csproj found nearby to format."
    return 0
  fi

  if dotnet format "$PROJ" --include "$FILE" >/dev/null 2>&1; then
    DOTNET_FORMAT_MESSAGE="SkyOps: ran dotnet format on $BASE."
  else
    DOTNET_FORMAT_MESSAGE="SkyOps: dotnet format on $BASE did not complete. Format manually before commit."
  fi
}

# --- standalone -------------------------------------------------------------
# Unchanged wire behaviour when this file is executed directly.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  RAW=''
  if [ ! -t 0 ]; then IFS= read -r -d '' RAW; fi
  dotnet_format_decide "$RAW"
  [ -n "$DOTNET_FORMAT_MESSAGE" ] && emit_message "$DOTNET_FORMAT_MESSAGE"
  exit 0
fi
