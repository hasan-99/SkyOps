---
id: rule-packs
title: Rule packs — load before the matching work
status: stable
---

# Rule packs — load before the matching work

Two packs are binding but topic-specific, so they load on demand:

| Load | Before you |
|---|---|
| `sky-rules-jira` | work, plan, review or comment on any Jira or PR |
| `sky-rules-data` | query a database or write a migration |

Not loading a pack is not permission to ignore it. **Load each at most once per session** — if unsure whether it is loaded, assume it is.

`sky-rules-memory` and `sky-rules-dotnet` were promoted into the always-loaded rules above: telemetry showed them at 4% and 3% of spend despite being ~520 and ~460 tokens, which is only possible by loading many times per session. Keep a pack on-demand only when its trigger is genuinely occasional, never when it fires on every edit.

## An explicit command means the decision is already made

If the user typed `/sky-task`, `/sky-fast`, `/sky-debug` or `/sky-test` — anywhere in the prompt — run that workflow directly. Do not invoke `sky-dispatch`, do not weigh alternatives, do not explain the fit. The only exception is the fast workflow's own escalation rule.
