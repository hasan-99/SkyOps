---
id: jira-workflow
title: Jira working conventions
status: stable
---

# Jira working conventions

## Read the whole ticket before planning

Read the full context before planning or coding — not just the description and comments, but **every** reference the ticket links to: Confluence pages, linked / related issues, and attached evidence. Never plan off the ticket's one-line paraphrase of a spec.

Fetch in parallel: the issue, its comments, every Confluence URL in the description or comments, every issue in `issuelinks`, and any attached evidence.

> `getConfluenceContent` without `detail: "full"` silently returns only a summary excerpt, which is easy to mistake for the page body. Always pass `detail: "full"`.

**Why:** a description that summarises the target logic in one line can omit the edge cases, tie-breakers and scope rules the real spec defines — planning off the paraphrase builds the wrong behaviour.

## One branch per Jira — standing default

As soon as a repo has changes for a ticket, create the branch. Do not ask each time, do not announce it:

- name it `HJ/CLS-<number>_<kebab-description>`, the **same name in every repo** that has changes
- base it on the **latest** dev — `git fetch` first; if local dev is behind `origin/dev`, branch from `origin/dev`
- the default branch is `dev` in CS_Datafactory_v2 and `Dev` in ClearSkiesPlatform
- never edit directly on `dev` / `Dev`

## Check out the branch for review work

For a code review or when resolving review comments, `git checkout` the review branch in each local repo rather than only diffing remote refs with `git show` / `git diff`.

**Why:** the user inspects changes in Visual Studio, which reflects the checked-out working tree. A remote-ref diff leaves nothing visible there.

If there is uncommitted work on the current branch, flag it before switching — never switch silently.

## Resolving the branch and repos

Read the branch from the ticket comments first (the "Branches for review" comment), or find it by Jira key. A ticket usually names more than one repo — resolve and review **all** of them. The comment often omits the branch prefix: if `origin/<name>` does not exist, run `git branch -a | grep -i <KEY>` and use the real name (commonly `MN/<KEY>`). If the branch was deleted after merge, fall back to the tagged commits.
