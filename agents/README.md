# SkyOps agents — model tiering

Agents are the **only** part of SkyOps whose model can be chosen. Skills and commands run on the session model and ignore a `model:` key entirely, so never add one there.

## The rule

> Cheap models find and fetch. Expensive models judge and decide.

Tier by **what a miss costs**, not by how much text the agent reads:

- **`opus`** — a miss is expensive, silent, and hard to catch later. Security holes and standards violations both ship quietly and surface in review or production.
- **`sonnet`** — real judgment, but scoped to one layer, and a miss is normally caught by the review round-trip or the build.
- **`haiku`** — pure fetch, scan, locate, or mechanical summary with no judgment. **No SkyOps agent currently qualifies.** Every review lane forms an opinion about code, which is exactly what the weakest tier is worst at.

## Current assignment

| Agent | Model | Why |
|---|---|---|
| `sky-srv-standards` | `opus` | Sweeps a diff against the **whole** SRV catalogue and is the mandatory lane. It is the one agent whose entire job is deciding. A missed SRV ships. |
| `sky-review-security` | `opus` | Auth, authorization, injection, secret handling, cross-tenant reachability. The failure mode is the most costly and the least visible. |
| `sky-review-api` | `sonnet` | Routing, verbs, status codes, contracts, controller thinness (SRV-L-004). Judgment, scoped to the API layer. |
| `sky-review-service` | `sonnet` | Handler correctness, SOLID, async and `CancellationToken` flow. Its SRV surface is double-covered by `sky-srv-standards`. |
| `sky-review-data` | `sonnet` | Query correctness, de-duplication, UoW boundaries, culture-sensitive parsing. Scoped to persistence. |
| `sky-review-performance` | `sonnet` | Must prove a real cost before reporting, so it needs judgment — but a missed N+1 is recoverable and usually visible in profiling. |
| `dotnet6-test-runner` | `sonnet` | Writes tests against an established xUnit + NSubstitute pattern. Pattern-following, not open-ended design. |

## History

- **2026-09-16** — `haiku` retired from `sky-review-api`. It was the only haiku lane and it judged routing, status codes and response contracts on the weakest tier, which produced thinner findings on that lane than on its four siblings. `sky-review-security` and `sky-srv-standards` moved up to `opus` at the same time, on the principle above.

## Before changing a tier

Ask what a **miss** costs, not what a run costs. Moving a lane down saves tokens on every review; it costs a round-trip the first time it misses something, and possibly a production incident if the lane was security or standards.
