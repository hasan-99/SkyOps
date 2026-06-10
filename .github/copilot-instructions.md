# Team GitHub Copilot Instructions

This repository uses shared CopilotOps instructions, prompts, and skills.

## General Rules

- Target .NET 6 and C# 10 unless a project explicitly says otherwise.
- Do not suggest .NET 7, .NET 8, .NET 9, or C# 11+ features for these backend projects.
- Prefer small, safe changes that follow existing project patterns.
- Do not over-engineer.
- Do not edit files, run builds, run tests, run migrations, install packages, or generate files when a planning prompt says to wait for `APPROVE PLAN`.
- Ask one blocking question only when required.
- For backend work, prefer the shared prompts in `.github/prompts`.
- For focused lane analysis, use the shared skills in `.github/skills`.
