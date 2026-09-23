---
name: sky-draft-comment
description: Drafts a short, paste-ready Jira completion comment for a ticket, with a repo and branch table, acceptance criteria marked done, and real test results. TRIGGER on any request to draft, write, prepare or update a Jira comment for a ticket, including the bare phrases "draft comment", "draft a comment", "draft the comment", "comment for CLS-NNNNN", "jira comment", "write up the ticket", "close out the ticket", or a request to summarise finished work for Jira. Fires on the plain-English phrasing, not only the slash command. Verifies branch, commit and test state before asserting anything. Never posts.
user-invocable: true
---

# Sky Draft Comment

Produces the comment that closes out implementation work on a ticket: what was built, in which
repo and branch, which acceptance criteria are met, and what the tests actually did.

This is the completion twin of `sky-review-finalize`. That one reports a review verdict and
findings. This one reports delivery. Do not merge their formats.

Invoke as `/sky-draft-comment <KEY>`. With no key, resolve it from the current branch name or the
active plan file, and say which key was assumed.

## When this fires

Run it without being asked to whenever the user asks for a Jira comment in their own words, not
just when they type the command. Any of these is a trigger:

- "draft comment", "draft a comment", "draft the comment"
- "comment for CLS-NNNNN", "jira comment", "add a comment to the ticket"
- "write up the ticket", "close out the ticket", "summarise this for Jira"

Firing means producing the draft in this format and stopping. It never means posting.

If the user asks for a *review* verdict with findings, that is `sky-review-finalize`, not this.

---

## Hard rules

1. **Never post.** Output the draft and stop. Drafting is not permission to post, and approval of
   the draft's wording is not approval to post it. Posting requires a separate explicit instruction
   for that specific action.
2. **Never mark an acceptance criterion done without evidence gathered in this session.** No
   evidence means it is not done, however obvious it looks.
3. **Never quote a test result from memory or from earlier in the conversation.** Either it ran in
   this session and you read the exit code, or the comment says it was not run.
4. **Markdown, not Jira wiki markup.** `addOrEditJiraIssueComment` takes markdown. `h3.`, `||` and
   `(/)` render as literal text.
5. **Short.** A long draft gets rejected. One paragraph of cause, no per-defect breakdown, no
   blast-radius prose, no SkyOps internals (lane, agent, skill or step names, catalogue paths).

---

## Gather before drafting

The formatting is the cheap part. This section is why the skill exists — every item here has
produced a wrong comment when skipped.

### 1. Acceptance criteria — from Jira, not from context

Fetch the ticket and read the acceptance criteria verbatim. Do not paraphrase them from what is
already in the conversation, and do not invent numbering the ticket does not have. Fold in any
still-valid comment that adds or narrows an AC.

If the ticket genuinely has no acceptance criteria, drop the AC table and say so in one line.

### 2. Branch and repo state — verify, never assume

For every repo touched, report the branch **and confirm it has commits**:

```bash
git -C <repo> branch --show-current
git -C <repo> rev-list --count origin/<base>..HEAD    # commits on the branch
git -C <repo> status --porcelain | wc -l              # uncommitted files
```

- **0 commits** means the branch name in the comment points at nothing. Do not publish a comment
  that implies reviewable work exists. Flag it above the draft and let the user decide.
- Uncommitted files mean the work is not on the branch yet. Say so.
- If the branch is not pushed, reviewers cannot fetch it. Say so.

### 3. Test evidence — from a run, with the exit code read

Run the affected suites, or report them as not run. Never infer a result from a pipe:

```bash
dotnet test <proj> --nologo -v q > /tmp/t.log 2>&1; echo "exit=$?"; grep -E "Failed!|Passed!" /tmp/t.log
```

Pre-existing failures are not yours, but only if proven: reproduce them on a clean checkout of the
target branch before calling them pre-existing in a comment other people will read.

### 4. Map each AC to its evidence

For every AC decide honestly:

- **✅ Done** — executed evidence exists (a test, a check, a read exit code).
- **✅ Done (structural)** — the design makes the failure impossible, but nothing executed proves
  it end to end. Say which, in the Notes section.
- **Not met** — say what is missing. Never round up to done.

---

## Output format

Show the draft in a fenced block so it can be copied, then stop.

```markdown
| Repo | Branch |
| --- | --- |
| <repo> | `<branch>` |
| <repo2> | `<branch>` |

### Cause

<one short paragraph — root cause only, no per-defect breakdown>

### Acceptance Criteria — all met

| # | Criterion | Status |
| --- | --- | --- |
| 1 | <AC text, from the ticket> | ✅ Done |
| 2 | <AC text> | ✅ Done |

### Tests — ✅ Done

- New: `<TestFile>.cs` — N tests. <one line on why they are trustworthy>
- `<suite>`: **N passed / N failed**
- Builds green.

### Notes

- <honest gap, out-of-scope item, or bystander confirmed unaffected>
```

Adjustments:

- Heading reads **"Acceptance Criteria — all met"** only when every row is done. Otherwise
  **"Acceptance Criteria"**, and the unmet rows say what is missing.
- Omit **Cause** for a feature or task where nothing was broken.
- Omit **Notes** only when there is genuinely nothing to disclose, which is rare.
- A test that is trustworthy because it was proven to fail against the old code is worth its one
  line. A test that has never failed proves nothing.

---

## After the draft

State, in one or two lines outside the fenced block:

- whether the branches actually have commits and are pushed
- anything in the draft that is structural rather than executed

Then offer to post, and wait. Do not post, commit, push, or transition the ticket as part of this
skill.
