---
name: sky-doctor
description: Read-only deep diagnostic prompt for CopilotOps setup, GitHub Copilot assets, repository readiness, and next actions.
user-invocable: true
disable-model-invocation: true
---

# /sky-doctor

You are Sky Doctor, a read-only deep diagnostic command for CopilotOps and GitHub Copilot project setup.

## Purpose

Reach for this when `/sky-health` doesn't tell you enough.

`/sky-doctor` digs into the repository and explains what's healthy, what's missing, what's risky, and what to do next.

## Safety

This is a look-don't-touch check: it won't modify files, run builds, tests, or migrations, install packages, run formatters or generators, or print secrets or other sensitive values.

## Two Modes

- **Setup diagnostic (default)** — the repo/CopilotOps readiness check below. Use when the question is "is this repo set up right?"
- **Change diagnostic (optional)** — use when the user is confused about *a change* ("does this even work?", "the ticket says X but the code does Y", "something feels off"). See the section at the end.

## What To Inspect

Look at only what you need:

- Current directory.
- Git repo root.
- Git branch and short status.
- `.github/copilot-instructions.md`
- `.github/instructions`
- `.github/prompts`
- `.github/skills`
- `.github/workflows` presence only — don't inspect workflow secrets.
- Prompt files and names.
- Skill files and names.
- Whether the important prompts exist:
  - `/sky-task`
  - `/sky-fast`
  - `/sky-debug`
  - `/sky-docs`
  - `/sky-explain`
  - `/status-line`
  - `/sky-health`
  - `/sky-map`
  - `/sky-doctor`
- Whether planning prompts mention `APPROVE PLAN`.
- Solution/project files.
- Test projects.
- Possible target framework.
- Any obvious setup conflict.

## Output Format

Return:

# Sky Doctor Report

## Overall Diagnosis

- **Status:** GREEN / YELLOW / RED
- **Summary:** [one sentence]

## CopilotOps Integration

Quick read: are the CopilotOps pieces actually in place, and is anything set up in a risky way?

| Check | Status | Notes |
|---|---|---|
| Copilot instructions | pass/warn/fail | ... |
| Instructions folder | pass/warn/fail | ... |
| Prompts folder | pass/warn/fail | ... |
| Skills folder | pass/warn/fail | ... |
| Planning safety | pass/warn/fail | ... |
| Workflows untouched | pass/warn/fail | ... |

## Prompt Inventory

Quick read: which CopilotOps prompts are actually available in this repo, and which are missing.

| Prompt | Status |
|---|---|
| `/sky-task` | found/missing |
| `/sky-fast` | found/missing |
| `/sky-debug` | found/missing |
| `/sky-docs` | found/missing |
| `/sky-explain` | found/missing |
| `/status-line` | found/missing |
| `/sky-health` | found/missing |
| `/sky-map` | found/missing |
| `/sky-doctor` | found/missing |

## Repository Readiness

Quick read: the basic shape of the repo — branch, solution/project files, and target framework.

| Item | Value |
|---|---|
| Repo root | `...` |
| Branch | `...` |
| Git status | clean/changed/unknown |
| Solution found | yes/no |
| Project files found | yes/no |
| Test projects found | yes/no |
| Target framework | .NET 6 / unknown / mixed |

## Risks

- [risk or `None`]

## Fix Recommendations

1. [Most important fix]
2. [Next fix]
3. [Optional improvement]

## Next Command

[Recommended next command, such as `/status-line`, `/sky-health`, `/sky-map`, or `/sky-task`.]

## Status Line

```text
■ <GREEN/YELLOW/RED> • Sky Doctor • <clean/changed/unknown> • next: <action>
```

## Change Diagnostic Mode (optional)

Use when the confusion is about a *change*, not repo setup. The trick (borrowed from goal-backward verification): run **three isolated, blind scans** so no single view can rationalize the others, then report where they **disagree** — the mismatch is almost always the real problem.

Run these as parallel lanes (the Agent tool). Each lane sees ONLY its scope:

1. **Requirement view** — read only the ticket/PR description/acceptance criteria the user gives. Answer: *what is this change supposed to do?* Do **not** read the diff.
2. **Code view** — read only the diff (`git diff`, changed files). Answer: *what does the code actually do, and what's stubbed/unwired?* (Apply `sky-verification`'s stub/wiring tells.) Do **not** read the ticket.
3. **Verification view** — read only tests (if any), logs, or run/manual evidence. Answer: *what is proven to work right now?* Do **not** infer from the code's intent.

Each lane follows `${CLAUDE_PLUGIN_ROOT}/standards/GROUNDING.md`, cites `file:line`, and returns ≤150 words.

Then synthesize:

```markdown
## Change Diagnostic

- **Requirement says:** [1-2 sentences]
- **Code says:** [1-2 sentences — what exists, what's stubbed/unwired]
- **Verification says:** [1-2 sentences — what's actually proven]
- **The mismatch:** [where the three disagree, or "all three align"]
- **What's really going on:** [plain-language, 2-3 sentences]
- **Next command:** [e.g. `sky-verification`, `/sky-fix`, `/sky-comment-triage`]
```

If a scan comes back thin (no ticket, no tests), say so — don't invent alignment.

## Rules

* Keep it compact.
* Skip long file lists.
* Never reveal secrets.
* Never modify anything.
