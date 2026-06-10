# CopilotOps Command Catalog

CopilotOps is the shared GitHub Copilot command, prompt, skill, and instruction toolkit for the team.

## Token-Saving Principle

Use small specialist lanes in parallel. Never give every agent the whole repository. Send each lane only the task summary, candidate files, and exact question it must answer.

CopilotOps is designed to reduce token usage by using focused parallel specialist agents instead of one large sequential investigation.

## Main Commands

| Command | Use When | Output | Safety |
|---|---|---|---|
| `/sky-task` | Large or cross-layer backend work | Full implementation plan | Waits for `APPROVE PLAN` |
| `/sky-fast` | Small-to-medium backend tasks | Compact implementation plan | Waits for `APPROVE PLAN` |
| `/sky-debug` | Bugs, exceptions, failing tests, wrong output | Root cause report and fix options | Waits for `APPROVE PLAN` |
| `/sky-docs` | Need documentation for a feature, endpoint, module, or flow | Markdown documentation | Read-only |
| `/sky-explain` | Need simple explanation of code or a feature | Plain-language explanation | Read-only |
| `/status-line` | Need repo/session status | Compact dashboard/status block | Read-only |
| `/sky-health` | Need to verify CopilotOps setup and repo readiness | Health check report | Read-only |
| `/sky-map` | Need a high-level architecture map | Project map and Mermaid diagram | Read-only |

## Internal Specialist Skills

| Skill | Focus |
|---|---|
| `sky-api` | Controllers, endpoints, DTOs, routes, contracts |
| `sky-service` | Services, validators, mappings, DI, business logic |
| `sky-data` | EF Core, DbContext, entities, repositories, migrations, queries |
| `sky-security` | Auth, authorization, tenant isolation, secrets, sensitive data |
| `sky-performance` | Query shape, async flow, hot paths, payload size, scalability |
| `sky-tests` | Existing test patterns, regression coverage, manual verification |

## Recommended Usage

Start with:

```text
/status-line
```

Then use:

```text
/sky-health
```

For small tasks:

```text
/sky-fast
```

For bigger tasks:

```text
/sky-task
```

For bugs:

```text
/sky-debug
```

For architecture discovery:

```text
/sky-map
```
