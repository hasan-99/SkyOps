# CopilotOps Team Onboarding

CopilotOps gives the team one shared way to use GitHub Copilot across repositories.

## Why We Use It

Before CopilotOps:
- Prompts were copied into each repo.
- Different projects could have different versions.
- Updating one command meant updating many repositories.
- New developers had no clear standard.

With CopilotOps:
- One source of truth.
- Shared commands across all projects.
- Safer planning before code changes.
- Consistent .NET 6 / C# 10 behavior.
- Easy onboarding for new team members.
- Lower token usage through focused parallel specialist lanes.

## Token-Saving Standard

Use small specialist lanes in parallel. Never give every agent the whole repository. Send each lane only the task summary, candidate files, and exact question it must answer.

CopilotOps is designed to reduce token usage by using focused parallel specialist agents instead of one large sequential investigation.

## First Commands To Run

Open a project under:

```text
C:\SharedProjects
```

Start with:

```text
/status-line
```

Then check setup:

```text
/sky-health
```

To understand the repo:

```text
/sky-map
```

## Common Workflows

### Small or Medium Task

Use:

```text
/sky-fast
```

### Large Task

Use:

```text
/sky-task
```

### Bug or Exception

Use:

```text
/sky-debug
```

### Explain Code

Use:

```text
/sky-explain
```

### Generate Documentation

Use:

```text
/sky-docs
```

## Safety Rule

Planning commands must wait for:

```text
APPROVE PLAN
```

Do not approve until the plan is reviewed.

## Team Standard

Do not copy shared prompts manually into each project.

Update CopilotOps once, and all linked projects receive the update.

Use focused parallel specialist agents for investigation. Do not run one large sequential scan when smaller lane-specific checks can answer the question with less context.
