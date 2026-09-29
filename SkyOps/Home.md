---
type: moc
tags: [moc, skyops]
author: Hasan Jahouse
version: 1.0
---

# SkyOps Framework — Vault Home

SkyOps is a Claude Code plugin for C#/.NET 6 backend work (v2.9.0). It is not a general framework — it's a set of **commands** (typed `/sky-*` entry points), **skills** (internal specialist inspectors the commands dispatch), **agents** (parallel review-lane subagents), **hooks** (deterministic harness automation), and a **standards catalogue** (the 16 SRV codes) that all interlock around one loop: catch defects at write-time, catch what slips past at review-time, and feed confirmed findings back into memory so the next write-time pass catches it sooner.

Open the **Graph view** (right sidebar) to see this — every note below links to what it calls and what calls it. Saved searches for fast filtering by type live in the **Bookmarks** pane ("SkyOps views" group, left sidebar).

## Start here — Architecture

- [[Choosing a Command]] — not sure which `/sky-*` to run? Start here.
- [[Repo Overview]] — what each top-level folder is for
- [[Working Flow]] — the end-to-end request flow, synthesized across both major commands
- [[Review Pipeline]] — the 12-step `/sky-review` orchestration, step by step
- [[Async Change Guard Pattern]] — how write-time guards and review-time lanes cooperate on the same SRV codes
- [[Hooks]] — the 4 deterministic harness hooks and what each does
- [[Changelog]] — version history, synced from `CHANGELOG.md`
- [[Vault Auto-Sync]] — the script that keeps this vault from drifting away from the real repo, regenerates the three Canvas boards ([[SkyOps Map]] — directory, no lines · [[Review Pipeline Map]] — sky-review's connections · [[Skills and Agents Map]] — skill↔agent pairs) and the changelog, and checks for broken links

## Standards

- [[SRV Catalog]] — all 16 SRV codes, severity letters, categories

## Commands (27) — typed `/sky-*` entry points

**Plan & execute**
[[sky-task]] · [[sky-fast]] · [[sky-debug]]

**Investigate**
[[sky-investigate]] · [[sky-forensics]] · [[sky-drift]]

**Review & comments**
[[sky-review]] · [[sky-comment-triage]] · [[sky-draft-comment]] · [[sky-jira-verify]] · [[sky-verify-fix]]

**Write-time guards** (self-fire, not just typed)
[[sky-async-guard]] · [[sky-i18n-guard]] · [[sky-sql-destructive-guard]]

**Scope & test**
[[sky-scope]] · [[sky-test]] · [[sky-test-gap]]

**PR & docs**
[[sky-pr]] · [[sky-docs]] · [[sky-explain]] · [[sky-map]]

**Meta / self-check**
[[sky-lint]] · [[sky-doctor]] · [[sky-health]] · [[status-line]]

**Learning loop**
[[sky-learn]] · [[sky-recall]] · [[sky-lesson-export]]

## Skills (18) — internal specialists the commands dispatch

**Plan-stage inspection lanes** (used by `/sky-task`, `/sky-fast`, `/sky-debug`)
[[sky-api]] · [[sky-data]] · [[sky-service]] · [[sky-security]] · [[sky-performance]] · [[sky-verification]]

**`/sky-review` internals**
[[sky-review-context]] · [[sky-review-scope]] · [[sky-review-flow]] · [[sky-review-finalize]] · [[sky-srv-select]]

**Judgement helpers**
[[sky-decision]] · [[sky-evidence]] · [[sky-risk]] · [[sky-change-summary]] · [[review-standards]] · [[sky-repo-profile]] · [[sky-next]]

## Agents (8) — parallel review-lane subagents dispatched only by `/sky-review`

[[sky-review-api]] · [[sky-review-data]] · [[sky-review-service]] · [[sky-review-security]] · [[sky-review-performance]] · [[sky-srv-standards]] · [[dotnet6-test-runner]] · [[sky-reader]]

## The key distinction

The 6 **plan-stage skills** (`sky-api`/`sky-data`/`sky-service`/`sky-security`/`sky-performance`/`sky-verification`) inspect code *before* it's written or while planning. Their same-named **review-time agents** (`sky-review-api`/`sky-review-data`/`sky-review-service`/`sky-review-security`/`sky-review-performance`) review a diff *after the fact*, dispatched only by [[sky-review]]. `sky-review` explicitly forbids dispatching the skill versions as review lanes — see [[Review Pipeline]].
