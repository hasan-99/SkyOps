#!/usr/bin/env bash
# UserPromptSubmit hook. Two jobs, in priority order:
#
#   1. DISPATCH - if the prompt is a request to work a ticket, hand off to the
#      sky-dispatch skill, which resolves the Jira, reads it, picks a workflow
#      and runs it. The user never types the slash command.
#   2. SUGGEST  - otherwise, fall back to the original behaviour: a short
#      reminder of the /sky-* commands that match the prompt's intent.
#
# A hook cannot invoke a slash command, so dispatch works by injecting the
# instruction to run the skill; the workflow definitions themselves live in
# skills/sky-workflow-*/ and are shared with the manual /sky-* commands.
#
# Ported from skyops-intent.js because node.exe takes 20-40s to start on this
# machine (Defender for Endpoint scans the 87MB binary on every launch), which
# blew the hook timeout on every prompt. Uses bash builtins only - no external
# commands - so this costs one ~2s spawn. Fails open (no output) on any error so
# it can never block a prompt.

# Read all of stdin using a builtin; -t guards against a writer that never closes.
IFS= read -r -d '' -t 10 input 2>/dev/null

[[ -z $input ]] && exit 0

# Pull "prompt":"..." out of the payload, tolerating escaped characters.
if [[ $input =~ \"prompt\"[[:space:]]*:[[:space:]]*\"((\\.|[^\"\\])*)\" ]]; then
  prompt=${BASH_REMATCH[1]}
else
  exit 0
fi

[[ -z $prompt ]] && exit 0

# An explicit slash command always wins - say nothing and let it run.
[[ ${prompt#"${prompt%%[![:space:]]*}"} == /* ]] && exit 0

prompt=${prompt,,}

out=()
implementing=0
framework_topic=0

has() {
  local w
  for w in "$@"; do
    [[ $prompt == *"$w"* ]] && return 0
  done
  return 1
}

# ---------------------------------------------------------------- dispatch ---
# A ticket key anywhere in the prompt, in any of the shapes people actually type.
ticket_key=''
if [[ $prompt =~ (cls)[-_\ ]?([0-9]{4,6}) ]]; then
  ticket_key="CLS-${BASH_REMATCH[2]}"
fi

# Work intent comes in two strengths.
#
# STRONG - names a concrete symptom or a concrete action. Unambiguous enough to
# dispatch on its own, so "the alerts export is not working" still routes to the
# debug workflow without anyone naming a ticket.
# SYMPTOM - self-evidencing. These name something going wrong, so they carry their own
# object and can dispatch alone: "the alerts export is not working" needs no ticket key.
symptom_intent=0
has "why is" "why does" "why are" "root cause" \
    "failing" "is broken" "not working" "crash" "exception" "stack trace" \
    "reproduce" && symptom_intent=1

# ACTION - a bare verb with no object. "implement", "fix", "debug" say what to do but
# not what to do it TO. On their own they match ordinary conversation about the tooling
# itself - "what should you do now to fix them all" dispatched a ticket workflow at a
# question about this very hook. An action verb must land on something concrete.
action_intent=0
has "implement" "fix " "fix the" "investigate" "debug" "run the tests" && action_intent=1

# A concrete thing an action verb can legitimately land on.
tech_noun=0
has "endpoint" "controller" "handler" "query" "migration" "test" "build" "api" \
    "alert" "export" "filter" "page" "component" "column" "table" "error" "bug" \
    "method" "service" "repository" "dto" "response" "request" "job" "script" && tech_noun=1

# Resolved below, after ticket_noun is computed.
strong_intent=0

# CONTINUATION - "carry on with the thing" . These are far too close to ordinary
# English to stand alone: the harness itself appends "Continue the task you were
# working on" after a usage-limit reset, which matched here and dispatched on a
# prompt the user never wrote. They require a ticket key or a ticket noun.
cont_intent=0
has "work on" "working on" "pick up" "start on" "continue with" "continue the" \
    "resolve " "finish " "complete the" "test " "verify " && cont_intent=1

ticket_noun=0
has "ticket" "jira" "cls-" "the issue" "story" "branch" "acceptance criteria" && ticket_noun=1

# An action verb dispatches only when it has an object: a ticket, or a concrete
# technical thing. A symptom dispatches on its own.
(( symptom_intent )) && strong_intent=1
(( action_intent && (tech_noun || ticket_noun) )) && strong_intent=1

# Explanation and review asks are NOT dispatch - they have their own commands.
explain_only=0
has "explain" "what does" "what is" "how does" "walk me through" \
    "review this" "review the" "code review" "should i" "which approach" && explain_only=1

# Questions ABOUT the tooling are not requests to run it. "can I roll back",
# "undo this", "restore the backup" must never start a workflow.
has "roll back" "rollback" "revert" "undo" "go back" "restore" "backup" \
    "previous version" "version before" && explain_only=1

# Naming SkyOps itself, without naming a ticket, means the prompt is ABOUT the
# framework - "is sky-jira-verify auto trigger?", "what model does sky-review use",
# "audit the skyops framework". With a real ticket key present this does not apply,
# so "work on CLS-1 with sky-fast" still dispatches.
#
# The test used to be `*"sky-"*` - with the hyphen - which missed the spelling people
# actually use most: "skyops". A prompt asking to improve the framework then matched
# the ordinary work triggers and dispatched a ticket workflow at it. Three separate
# prompts in one session hit this before it was found.
if [[ -z $ticket_key ]] && \
   [[ $prompt == *"sky-"* || $prompt == *"skyops"* || $prompt == *"sky ops"* || \
      $prompt == *"framework"* || $prompt == *"the audit"* || $prompt == *"findings"* ]]; then
  explain_only=1
  framework_topic=1
fi

# Question forms aimed at the tooling rather than at the code.
has "auto trigger" "auto-trigger" "auto triiger" "automatically trigger" \
    "how many" "list the" "difference between" "do they" "does it" "are they" \
    "which model" "what model" && explain_only=1

# A long prompt is pasted material - a table, a log, a spec - not a terse order to
# go work a ticket. Substring matching across a big paste is almost always a false
# positive ("dotnet-debugging" in a pasted list matched the "debug" trigger). A real
# work request is short, or it names a ticket key.
if [[ -z $ticket_key && ${#prompt} -gt 600 ]]; then explain_only=1; fi

# Past this length it is pasted material even if a key appears in it - a ticket key
# inside a quoted example, a spec, or a folder listing is not a request to go work
# that ticket. A real order naming a ticket is short.
if [[ ${#prompt} -gt 1500 ]]; then explain_only=1; fi

if [[ -n $ticket_key || $strong_intent -eq 1 || ( $cont_intent -eq 1 && $ticket_noun -eq 1 ) ]] \
   && [[ $explain_only -eq 0 ]]; then
  # Terse on purpose: this fires on every ticket prompt, and sky-dispatch's own
  # description already carries the procedure. Repeating it here is paid twice.
  if [[ -n $ticket_key ]]; then
    echo "SkyOps: run sky-dispatch for $ticket_key (route, do not just suggest)."
  else
    echo "SkyOps: run sky-dispatch; resolve the ticket from branch/plan/memory first."
  fi
  exit 0
fi

# ---------------------------------------------------------------- suggest ----
#
# Guards the suggest half used to lack entirely. Dispatch had six anti-false-positive
# patches; suggest had none, so a pasted document could match a dozen triggers at once
# and emit a wall of irrelevant commands. Pasting a framework audit produced NINE
# suggestions - none of them useful, all of them paid for.

# A prompt ABOUT the framework is not a request to run the framework.
(( framework_topic )) && exit 0

# Long prompts are pasted material - a spec, a log, a table, a document. Substring
# matching across a big paste is almost always a false positive. Dispatch already
# applies this rule; suggest needs it more, because it matches far more patterns.
[[ ${#prompt} -gt 800 ]] && exit 0

add() {
  local e
  for e in "${out[@]}"; do
    [[ $e == "$1" ]] && return 0
  done
  out+=("$1")
}

# Reviewing a Jira / PR / reviewer comment
if has "review comment" "reviewer" "jira comment" "pr comment" \
       "pull request comment" "resolve comment" "address comment" \
       "reviewer said" "reviewer asked" "comment on my jira" "comment on the pr"; then
  add "/sky-comment-triage  (validate the comment vs real code before acting)"
fi

# Applying / implementing a change or fix
if has "apply change" "applying change" "apply the change" "implement" \
       "make the change" "make this change" "apply the fix" "apply fix" \
       "write the code" "add the method" "resolve the comment" "address the comment"; then
  add "/sky-risk  (what could break, before you edit)"
  add "/sky-verification  (confirm it's real + wired, after you edit)"
  implementing=1
fi

# Reviewing code / a PR
if has "review this" "review the" "code review" "look over" "check this pr" "review pr"; then
  add "/sky-review  (SRV-graded review)"
fi

# Checking a branch actually covers the Jira requirements
if has "requirement" "acceptance criteria" "does it cover" "did i miss" "cover the ticket"; then
  add "/sky-jira-verify  (branch vs Jira requirement coverage)"
fi

# Investigation / debugging / root cause
if has "investigate" "root cause" "why is" "why does" "debug" "trace the" "where does"; then
  add "/sky-investigate"
fi

# Security-sensitive work
if has "security" "auth" "injection" "vulnerab" "sanitize" "sensitive data"; then
  add "/sky-security"
fi

# Performance-sensitive work
if has "performance" "slow" "n+1" "optimize" "latency" "timeout"; then
  add "/sky-performance"
fi

# Choosing between approaches
if has "which approach" "should i" "trade-off" "tradeoff" "option a" "better way" "decide between"; then
  add "/sky-decision"
fi

# Debugging a concrete error / exception / failing test
if has "stack trace" "exception" "error message" "failing test" "test is failing" \
       "not working" "throws" "null reference" "nullref" "bug in"; then
  add "/sky-debug"
fi

# Explaining existing code
if has "explain" "what does this" "what does the" "how does this work" \
       "walk me through" "understand this code" "what is this code"; then
  add "/sky-explain"
fi

# Architecture / structure overview
if has "architecture" "how is this structured" "project structure" \
       "how is the code organized" "map the" "codebase overview" "high level overview"; then
  add "/sky-map"
fi

# Opening / creating a PR (outward action -> confirm before it posts)
if has "open a pr" "create a pr" "raise a pr" "make a pr" "open pr" \
       "create pr" "raise pr" "submit the pr" "ready for pr"; then
  add "/sky-pr  (outward action — confirm before it posts)"
fi

# About to push -> nudge a final review pass
if has "before push" "before i push" "ready to push" "about to push" \
       "before merging" "before merge"; then
  add "/sky-review  (heavy — run a final SRV-graded pass before pushing)"
fi

# Standalone risk / verify asks (only if not already added above)
has "risk" "what could break" "impact of" "is it safe" && add "/sky-risk"
has "verify" "does this work" "is it wired" "did it actually" "confirm it works" && add "/sky-verification"

(( ${#out[@]} == 0 )) && exit 0

# Emit at most two. The footer always said "run AT MOST the one or two most relevant",
# so printing nine and then asking for two paid for seven that were going to be thrown
# away. Matching more patterns is weaker evidence, not stronger: a prompt that trips six
# different triggers is almost always a paste, not a request for six commands. Order in
# the checks above is rough priority, so the first two are the most specific matches.
dropped=$(( ${#out[@]} - 2 ))
(( dropped > 0 )) && out=("${out[@]:0:2}")

echo "SkyOps suggestions for this request:"
for s in "${out[@]}"; do
  echo "  - $s"
done
(( dropped > 0 )) && echo "  ($dropped weaker match(es) not shown.)"
if (( implementing )); then
  echo "SRV compliance: write to the standard as you go (H-001 no sync-in-async, L-010 thread CancellationToken, H-006 InvariantCulture datetimes, L-004 thin controllers, M-003 UoW=transaction). Self-check the diff vs SRV-CATALOG or run /sky-review before push."
fi
echo "Run AT MOST the one or two most relevant; skip any that don't fit. All read-only, token-disciplined (<=5 findings)."
exit 0
