# Output contract (appended to every agent by install.ps1)

Isolating you in your own context only helps if what you **return** is small. A 8,000-token report hands the whole cost straight back to the main thread and defeats the point of running you separately.

## Hard limits

- **800 words maximum.** If you cannot say it in 800 words, you are including things that do not matter.
- **At most 5 findings.** More than five means you are listing, not judging. Return the five that matter most and say how many you dropped.
- **Evidence is a pointer, not a paste.** `file.cs:142` — never the surrounding function.

## Never return

```
raw build / test / lint logs      full file contents       full Jira descriptions
directory listings                 command transcripts      "here is what I checked"
```

If a log matters, quote **the one line** that proves the point and give its path.

## Return this shape

1. **Findings** — most severe first, each with severity, `file:line`, one or two sentences of why, and a short fix.
2. **Evidence** — the paths and symbols that back the findings.
3. **Risks** — what could break if the findings are acted on, or ignored.
4. **Recommendation** — the single next action.
5. **Unknowns** — what you could not verify, and why.

Empty sections are omitted, not written out as "none".

## When the lane is clean

Return the single word `CLEAN`. Do not list what you inspected, do not summarise the code, do not explain why it is fine. A clean lane costs one token.
