---
type: architecture
tags: [architecture, skyops, guide]
author: Hasan Jahouse
version: 1.0
---

# Choosing a Command

The planning/investigate commands overlap on purpose — they trade depth for speed differently. This is the quick way to pick.

```mermaid
flowchart TD
    A["Need help from SkyOps"] --> B{"What do you have?"}
    B -- "a Jira ticket to implement" --> C{"how big?"}
    C -- "small / medium" --> D["/sky-fast"]
    C -- "large / multi-phase" --> E["/sky-task"]
    B -- "a bug, cause unknown" --> F["/sky-debug"]
    B -- "something's off, scope unclear" --> G{"how deep?"}
    G -- "backend / SQL / data digging" --> H["/sky-investigate"]
    G -- "full incident reconstruction" --> I["/sky-forensics"]
    G -- "did the fix actually ship?" --> J["/sky-drift"]
    B -- "a finished branch to review" --> K["/sky-review"]
    B -- "a reviewer left a comment" --> L["/sky-comment-triage"]
    B -- "ticket's done, need Jira text" --> M{"which text?"}
    M -- "review verdict" --> N["/sky-review (drafts it)"]
    M -- "completion comment" --> O["/sky-draft-comment"]
    M -- "did I cover every requirement?" --> P["/sky-jira-verify"]
    D --> Q["writes a plan, waits for APPROVE PLAN"]
    E --> Q
    F --> Q
```

## The distinctions that matter

- **[[sky-fast]] vs [[sky-task]]** — same `APPROVE PLAN` gate, different cost. `sky-fast` inspects directly for small work; `sky-task` dispatches the full plan-stage skill set and writes phases/waves for larger work.
- **[[sky-debug]] vs [[sky-investigate]] vs [[sky-forensics]]** — increasing scope. `sky-debug` traces one bug to the smallest fix. `sky-investigate` digs wider across backend/SQL/data/incident. `sky-forensics` is full incident reconstruction.
- **[[sky-drift]]** isn't about finding a bug — it's about whether a fix that was already written actually merged and is actually running.
- **[[sky-review]] vs [[sky-comment-triage]]** — `sky-review` is the full orchestrated pass; `sky-comment-triage` verifies one specific reviewer comment is even right before acting on it.

## See also

[[Working Flow]] · [[Home]]
