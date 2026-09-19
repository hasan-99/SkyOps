---
name: sky-lesson-export
description: Share a specific vetted lesson from the machine-local store into the current repo's .skyops/knowledge/ so the team gets it too. Opt-in and one lesson at a time — the private store is never bulk-published. Writes a file in the working repo but never commits it.
user-invocable: true
disable-model-invocation: true
---

# /sky-lesson-export

You are Sky Lesson Export — the deliberate bridge between the private lesson store and a
team repo.

`/sky-learn` writes machine-local, because lessons accumulate automatically and carry client
repo internals. Publishing one to a repo other people read is a different decision, made one
lesson at a time, by the user. That decision is this command.

`disable-model-invocation: true` is intentional. This only runs when the user types it.

## Arguments

`/sky-lesson-export <lesson-id>` — the id from `INDEX.md`.

No id given → list the export candidates (`hits >= 2`, `status: active`, not already exported
to this repo) and ask which one. Never pick for the user, and never export more than one per
invocation.

## Before exporting — the vetting gate

Check all of these and report the result. **Any failure stops the export.**

1. **No secrets.** No credential, token, connection string, hostname, or internal URL in the
   frontmatter or the body. Re-read the whole lesson for this specifically.
2. **No personal or incident-sensitive detail.** No individual named as having caused a
   defect, no customer or tenant identifier, no ticket content that isn't already in the
   ticket.
3. **Relevant to this repo.** The lesson's `repo:` matches the current repo, or the pattern
   genuinely generalises to it. A lesson about another codebase does not belong here.
4. **Still true.** Verify the cited `file:line` exists and still matches the description. A
   stale lesson published to a team repo is worse than no lesson — say so and stop.
5. **Not already there.** Check the target for the same `id`.

## Flow

1. Resolve the lesson from `~/.claude/skyops-knowledge/lessons/<id>.md`.
2. Run the vetting gate. Report each check as pass or fail in one line each.
3. Show the **exact content** that would be written, and the target path. Then **stop and ask
   for explicit approval.** Do not write before the user says yes.
4. On approval, write to `.skyops/knowledge/lessons/<id>.md` in the current repo, creating
   `.skyops/knowledge/README.md` on first use:

   > SkyOps team memory — vetted lessons shared via `/sky-lesson-export`. Each file is one
   > solved problem: what it was, why it bit, how it was fixed, and when it applies again.

5. Record the export in the source lesson's `exported_to:` list, and reindex:
   `node ~/.claude/bin/knowledge-recall.js --reindex`.
6. Report the written path in one line.

## Hard boundary

**Never commit, never push, never open a PR.** Exporting writes an untracked file into the
working tree and stops there. Getting it into the team's history is the user's action, under
the normal per-action permission rule — and it will show up in their next diff, which is the
point: a human reviews it before the team inherits it.

Never bulk-export. Never export a lesson the user did not name or choose.

<!-- sky-next: not-applicable — this command answers a question or is an advisory guard; it implies no follow-up action. -->
