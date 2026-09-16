---
id: secrets
title: Secret handling
status: stable
---

# Secret handling

Never print, echo, log, paste, or quote a credential value — not in a report, not in a commit message, not in a Jira comment, not to confirm you found it.

SkyOps source **must never contain a secret**. `memory/` in the SkyOps repo is version controlled; a credential written there is a credential published.

A memory or rule may record only:

- where the credential comes from
- which secret mechanism holds it
- how to invoke the tool safely
- that the value must never be printed

Machine-local credentials live in `~/.claude/skyops-secrets.local.md`, which SkyOps splices into the generated `CLAUDE.md` at install time and never reads into the repo. Preferred mechanisms, in order: company vault, Windows Credential Manager, environment variable, then the local file.

If you find a real credential sitting in a file that should not hold one, report the location and the risk **without printing the value**, and leave the value untouched until the user decides how to migrate it.
