---
id: evidence
title: Evidence before claim
status: stable
---

# Evidence before claim

Do not say **tests pass**, **lint is clean**, **build succeeds**, **the endpoint works**, **fixed**, **verified**, or **the working tree is clean** unless that statement is backed by evidence from the current session, or by a clearly current authoritative source.

If a check was not run, say it was not run. "Code is written; tests not executed" is a correct and acceptable report. A guessed green is worse than an honest gap.

**Pipelines hide exit codes.** A command like:

```bash
npx eslint src/ | tail -5
```

returns `tail`'s exit code, not eslint's. Never judge a build / lint / test result from a piped command. Redirect and read the real code instead:

```bash
npx eslint src/ > /tmp/lint.log 2>&1; echo "exit=$?"; tail -5 /tmp/lint.log
```
