---
type: architecture
tags: [architecture, skyops, vault-tooling]
author: Hasan Jahouse
version: 1.0
---

# Vault Auto-Sync

`scripts/sky-generate-vault.js` — keeps this vault from drifting away from the real `commands/`, `skills/`, and `agents/` frontmatter, and regenerates three derived Canvas boards from whatever wikilinks actually exist in the vault.

## What it syncs

For every command (`commands/*.md`), skill (`skills/*/SKILL.md`), and agent (`agents/*.md`) in the live repo, it finds the matching vault note by filename and writes one small machine-owned block right after the frontmatter, delimited by `<!-- sky-sync:start -->` / `<!-- sky-sync:end -->`: repo source path, the repo's own `description:`, and `user-invocable`/`disable-model-invocation` (or `model`/`tools` for agents). That block is fully replaced on every run. **Everything outside it — all hand-authored prose — is left untouched.**

If a command/skill/agent has no matching vault note at all, it creates a minimal stub (frontmatter + sync block + a `TODO: describe` line) so nothing silently goes undocumented — a human still has to come back and write the real content. This is how [[status-line]] got caught the first time: it existed in `commands/` but had no vault note yet.

## What it regenerates

Three Canvas boards, all fully derived, never hand-edited — split apart deliberately after the first version tried to put all 423 wikilink edges on one board and made it unreadable:

- **[[SkyOps Map]]** — every note, laid out in columns by type (Home / Architecture / Standards / Commands / Skills / Agents). **Zero edges, on purpose.** It's a directory, not a link map — use a note's Backlinks/Outgoing panes or the Graph view for that. Two nodes at the bottom point at the two boards below.
- **[[Review Pipeline Map]]** — a hub-and-spoke star around `sky-review`: the command itself plus everything one hop away, but edges are kept to only those touching `sky-review` directly (its neighbors are heavily cross-linked with *each other* too — including those edges reproduced the same density problem at a smaller scale).
- **[[Skills and Agents Map]]** — only skill↔agent cross-links (the plan-stage-skill to review-time-agent counterpart pairs). Every command/architecture link is dropped, so this stays small regardless of how the vault grows.

**[[Changelog]]'s version table** — synced from `CHANGELOG.md`'s `## [version] - title` headers into a table, same sync-block mechanism as the command/skill/agent notes. Full entries stay in `CHANGELOG.md`; the note is an index, never a copy.

## Link check

Every run also parses every wikilink in the vault and checks it against every real note and Canvas file. Read-only — it reports broken links, it never fixes them, because a broken link is a decision (fix the wording, or the target genuinely needs a note) that belongs to a human. The process exits non-zero if any are found, so it can gate CI.

## Usage

```
node scripts/sky-generate-vault.js            # sync notes + rebuild canvases + link check
node scripts/sky-generate-vault.js --dry-run   # report only, write nothing
node scripts/sky-generate-vault.js --canvas-only   # skip note/changelog sync
node scripts/sky-generate-vault.js --selftest  # sanity-check the parser
```

No external dependencies — plain Node `fs`/`path`, same convention as [[Review Pipeline|scripts/lane-gate.js]].

## See also

[[Repo Overview]] · [[Home]]
