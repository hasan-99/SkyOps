#!/usr/bin/env bash
# PostToolUse (Edit|Write) nudge: after a C# SOURCE edit in CS_Datafactory_v2,
# remind the model to close the test loop with /sky-test diff.
# Emits nothing for anything else, so it is silent outside that repo's source.
# Ported from sky-test-nudge.js - node.exe costs 20-40s to start here, which
# taxed every single Edit/Write. Bash builtins only: one ~2s spawn.

IFS= read -r -d '' -t 10 input 2>/dev/null

[[ -z $input ]] && exit 0

# tool_input.file_path is the normal shape; fall back to tool_response.filePath.
if [[ $input =~ \"file_path\"[[:space:]]*:[[:space:]]*\"((\\.|[^\"\\])*)\" ]]; then
  fp=${BASH_REMATCH[1]}
elif [[ $input =~ \"filePath\"[[:space:]]*:[[:space:]]*\"((\\.|[^\"\\])*)\" ]]; then
  fp=${BASH_REMATCH[1]}
else
  exit 0
fi

[[ -z $fp ]] && exit 0

# Un-escape the JSON string, then normalize to lowercase forward slashes.
fp=${fp//\\\\//}
fp=${fp//\\//}
p=${fp//\\//}
p=${p,,}

# Only this repo.
[[ $p == */cs_datafactory_v2/* ]] || exit 0
# Only C# source.
[[ $p == *.cs ]] || exit 0

# Skip the test tree itself (we're nudging about the source that changed).
[[ $p == */test/* ]] && exit 0
[[ $p == *.tests/* ]] && exit 0

# Skip generated / build / non-unit-tested artifacts.
[[ $p == */obj/* || $p == */bin/* ]] && exit 0
[[ $p == */migrations/* ]] && exit 0
[[ $p == *.g.cs || $p == *.designer.cs ]] && exit 0
[[ $p == */assemblyinfo.cs || $p == *assemblyattributes.cs ]] && exit 0

name=${fp//\\//}
name=${name##*/}

# Fire once per file per session. Ten edits to the same file used to inject ten copies
# of the identical ~175-token reminder - 1,750 tokens saying one thing. The marker is
# keyed by the session id when the payload carries one, so a new session nudges again.
sid=''
[[ $input =~ \"session_id\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && sid=${BASH_REMATCH[1]}
marker_dir="${TMPDIR:-/tmp}/sky-test-nudge/${sid:-default}"
key=${p//[^a-z0-9]/_}
if [[ -e "$marker_dir/$key" ]]; then
  exit 0
fi
mkdir -p "$marker_dir" 2>/dev/null && : > "$marker_dir/$key" 2>/dev/null

context="You just edited C# source in CS_Datafactory_v2 (${name}). \
Before treating this change as done, close the test loop with /sky-test diff: \
map the change to the tests that cover it, edit existing tests or create missing ones \
in the repo's xUnit + NSubstitute style (plain Assert, per-module CreateSut/InMemory-vs-mock convention), \
run only the affected tests, fix failures within budget, and commit per the run's commit mode \
(ask-first unless commit=auto). If this edit was itself a test file or has no runtime surface, ignore this."

printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}' "$context"
exit 0
