---
id: review-and-code-style
title: Review output and code style
status: stable
---

# Review output and code style

## sky-review report lead

Line one: `<KEY> — <verdict>` — a plain verdict word (Approved / Approved With Comments / Changes Requested / Blocked). No `Sky Review:` prefix, no ticket title.
Line two: **one** plain sentence — what was implemented, build result, tests.
Then the findings.

Do not list every sub-change, the test class name, or a Branches line in the lead.

## No live-verification padding

Never include a "verified live on Dev", "manual verification", "outside review", or release-gate line or row — not in the report, not in the AC table, not in the Jira comment. If an acceptance criterion is a manual or live check, drop it silently. Report only what is verified from code, build, and tests.

**Why:** the user asked for this repeatedly and emphatically; it reads as padding on every review. Follow it even if an older loaded command version still describes a verification phase.

## Code comments

Keep comments in source minimal — one concise line over a multi-line block — and never put a Jira ticket number in a code comment. The ticket reference belongs in the commit message and the Jira comment. This governs code comments only; commit and Jira conventions are unchanged.
