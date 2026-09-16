#!/usr/bin/env bash
# PreCompact hook. Fires immediately before context is compacted or cleared.
#
# Why this exists: telemetry shows 86% of token spend happens in sessions already
# above 150k context, which means compaction is a routine event, not a rare one.
# Compaction summarises the conversation - and a summary reliably loses the small
# operational facts that matter most later: whether the branch was pushed, which
# acceptance criteria are still open, what a reviewer asked for. Those live only in
# the transcript until something writes them down.
#
# This hook writes nothing itself. It injects one short instruction telling the model
# to persist ticket state to memory BEFORE the window is discarded. That is the whole
# job: a checkpoint prompt at the one moment it cannot be deferred.
#
# Bash builtins only - node costs 20-40s to start on this machine. Fails open.

IFS= read -r -d '' -t 10 input 2>/dev/null

# trigger is "manual" (/compact or /clear typed) or "auto" (window full).
trigger=''
if [[ $input =~ \"trigger\"[[:space:]]*:[[:space:]]*\"([a-z]*)\" ]]; then
  trigger=${BASH_REMATCH[1]}
fi

msg="Context is about to be compacted, so anything not written down is about to be lost. \
Before the summary is produced: if this session touched a Jira ticket, run sky-memory-sync \
now and make the ticket's memory entry true - ticket_state, branch, what is committed, what \
is pushed, what is posted, which acceptance criteria remain, and any assumption this session \
disproved. If a plan file is open, make sure its Requirement Status and Execution Log reflect \
reality. Do not restate the work in the reply; just persist it. If no ticket is in play, ignore this."

if [[ $trigger == "manual" ]]; then
  msg="$msg Note the user triggered this deliberately - if they typed /clear they are switching \
tasks, so finish persisting state rather than trying to carry it forward."
fi

esc=${msg//\\/\\\\}
esc=${esc//\"/\\\"}
esc=${esc//$'\n'/ }

printf '{"hookSpecificOutput":{"hookEventName":"PreCompact","additionalContext":"%s"}}' "$esc"
exit 0
