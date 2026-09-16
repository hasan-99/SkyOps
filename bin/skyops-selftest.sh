#!/usr/bin/env bash
# SkyOps self-test. Runs the behaviour, not the file listing.
#
# Why this exists: every bug this framework has shipped was invisible to the checks
# it had. `/sky-doctor` verified files existed - so a guard script that no hook
# called, five skills the model could not invoke, and a `find` command that took the
# wrong argument and searched the wrong store all passed inspection for a long time.
# The linter in install.ps1 catches wiring; this catches behaviour.
#
# Every case here is a bug that actually happened.
#
#   skyops-selftest.sh          run all
#   skyops-selftest.sh -v       show actual output on failure

set -u
BIN="$(cd "$(dirname "$0")" && pwd)"
VERBOSE=0
[[ ${1:-} == -v ]] && VERBOSE=1
PASS=0; FAIL=0; FAILED=()

ok()   { PASS=$((PASS+1)); printf "  \033[32mPASS\033[0m  %s\n" "$1"; }
bad()  { FAIL=$((FAIL+1)); FAILED+=("$1"); printf "  \033[31mFAIL\033[0m  %s\n" "$1"
         (( VERBOSE )) && printf "        got: %s\n" "${2:-<empty>}"; }

# expect_out <name> <expect-substring|EMPTY> <actual>
expect() {
  local name=$1 want=$2 got=${3:-}
  if [[ $want == EMPTY ]]; then
    [[ -z $got ]] && ok "$name" || bad "$name" "$got"
  else
    [[ $got == *"$want"* ]] && ok "$name" || bad "$name" "$got"
  fi
}

echo
echo "  SkyOps self-test"
echo

# ---------------------------------------------------------------- guard hook --
# Bug: bin/sky-guard.sh existed but was wired nowhere, so nothing enforced the
# destructive-action rule.
echo "  sky-guard.sh (destructive git/SQL)"
G="$BIN/sky-guard.sh"
g() { printf '{"tool_input":{"command":"%s"}}' "$1" | bash "$G" 2>/dev/null; }
expect "force push asks"           '"permissionDecision":"ask"' "$(g 'git push --force origin main')"
expect "reset --hard asks"         '"permissionDecision":"ask"' "$(g 'git reset --hard HEAD~1')"
expect "git clean -fd asks"        '"permissionDecision":"ask"' "$(g 'git clean -fd')"
expect "DELETE no WHERE asks"      '"permissionDecision":"ask"' "$(g 'sqlcmd -Q \"DELETE FROM Alerts\"')"
expect "commit on dev asks"        '"permissionDecision":"ask"' "$(cd "$BIN/.." 2>/dev/null; g "git commit -m x")"
expect "force-with-lease allowed"  EMPTY                        "$(g 'git push --force-with-lease')"
expect "ls allowed"                EMPTY                        "$(g 'ls -la')"
expect "reading a .sql allowed"    EMPTY                        "$(g 'cat migrations/001_add_column.sql')"

# --------------------------------------------------------------- intent hook --
# Bug: the framework-detection guard tested for "sky-" with a hyphen, so prompts
# about "skyops" dispatched a ticket workflow. Misfired three times in one session.
echo
echo "  skyops-intent.sh (routing)"
I="$BIN/skyops-intent.sh"
i() { printf '{"prompt":"%s"}' "$1" | bash "$I" 2>/dev/null; }
expect "ticket key dispatches"     "sky-dispatch for CLS-15379" "$(i 'work on CLS-15379')"
expect "symptom dispatches"        "sky-dispatch"               "$(i 'the alerts export is not working')"
expect "verb+object dispatches"    "sky-dispatch"               "$(i 'fix the alerts export')"
expect "framework talk silent"     EMPTY                        "$(i 'deep check the skyops framework and save tokens')"
expect "bare verb silent"          EMPTY                        "$(i 'what should you do now to fix them all')"
expect "tooling question silent"   EMPTY                        "$(i 'is sky-jira-verify auto trigger')"
expect "slash command silent"      EMPTY                        "$(i '/sky-task CLS-1')"
long=$(printf 'implement the endpoint %.0s' {1..60})
expect "long paste silent"         EMPTY                        "$(i "$long")"

# ----------------------------------------------------------------- nudge hook --
# Bug: fired on every Edit/Write, re-injecting the same ~175-token reminder.
echo
echo "  sky-test-nudge.sh (once per file per session)"
N="$BIN/sky-test-nudge.sh"
rm -rf "${TMPDIR:-/tmp}/sky-test-nudge/selftest"
P='{"session_id":"selftest","tool_input":{"file_path":"C:\\SharedProjects\\CS_Datafactory_v2\\src\\Foo.cs"}}'
first=$(printf '%s' "$P" | bash "$N" 2>/dev/null)
second=$(printf '%s' "$P" | bash "$N" 2>/dev/null)
expect "first edit nudges"         "sky-test"  "$first"
expect "second edit silent"        EMPTY       "$second"
expect "other repo silent"         EMPTY       "$(printf '{"session_id":"selftest","tool_input":{"file_path":"C:\\Other\\x.cs"}}' | bash "$N" 2>/dev/null)"
expect "test file silent"          EMPTY       "$(printf '{"session_id":"selftest","tool_input":{"file_path":"C:\\SharedProjects\\CS_Datafactory_v2\\test\\FooTests.cs"}}' | bash "$N" 2>/dev/null)"

# ------------------------------------------------------------- precompact hook --
echo
echo "  sky-precompact.sh (persist before context loss)"
expect "emits persist instruction" "sky-memory-sync" "$(printf '{"trigger":"auto"}' | bash "$BIN/sky-precompact.sh" 2>/dev/null)"
expect "fails open on empty"       "PreCompact"      "$(printf '' | bash "$BIN/sky-precompact.sh" 2>/dev/null)"

# ---------------------------------------------------------------- memory find --
# Bug: `find <term>` threw (Query was not positional), and it searched only the
# store matching the cwd - so from a repo it reported "no match" for entries that
# exist. Memory is now fetched on demand, so a false "no match" silently causes a
# fact to be re-derived. This is the test that should have existed.
echo
echo "  skyops-memory.ps1 find (lookup, from any cwd)"
MEM="$BIN/skyops-memory.ps1"
if command -v pwsh >/dev/null 2>&1 && [[ -f $MEM ]]; then
  m() { (cd "$1" && pwsh -NoProfile -ExecutionPolicy Bypass -File "$MEM" find "$2" 2>&1); }
  expect "positional arg works"      "sqlcmd"   "$(m "$HOME" sqlcmd)"
  expect "finds from a foreign cwd"  "sqlcmd"   "$(m "$BIN/.." sqlcmd)"
  expect "searches the archive"      "CLS-14779" "$(m "$BIN/.." CLS-14779)"
  expect "honest on no match"        "No memory entry matches" "$(m "$HOME" zzzznotathing)"
else
  echo "  SKIP  pwsh or skyops-memory.ps1 unavailable"
fi

# ---------------------------------------------------------------------- report --
echo
if (( FAIL == 0 )); then
  printf "  \033[32m%d passed, 0 failed\033[0m\n\n" "$PASS"
  exit 0
fi
printf "  \033[31m%d passed, %d FAILED\033[0m\n" "$PASS" "$FAIL"
for f in "${FAILED[@]}"; do printf "        - %s\n" "$f"; done
echo
exit 1
