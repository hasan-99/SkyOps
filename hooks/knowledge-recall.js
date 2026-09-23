#!/usr/bin/env node
// SkyOps knowledge engine — deterministic recall + index builder.
//
// Two jobs, one file:
//
//   1. UserPromptSubmit hook (no args): scores the user's prompt against the
//      lesson store and injects the strongest matches as additionalContext.
//      This is what makes recall deterministic — it does not depend on the
//      model remembering to call /sky-recall.
//
//      PREFER knowledge-recall.sh FOR THIS. It is a behaviour-identical bash
//      port, and it is the one to wire wherever bash exists: node costs ~9.3s
//      per spawn on a Defender-scanned Windows box against ~1.2s for bash
//      (measured), and this hook fires on every prompt. Keep the JS path for
//      portability, not for daily use.
//
//   2. `node knowledge-recall.js --reindex`: rebuilds INDEX.md (for humans and
//      /sky-recall) and index.json (for this hook) from lessons/*.md.
//      Also `--list` to dump the index, `--stats` for recurrence counts.
//
// Store location: $SKYOPS_KNOWLEDGE_DIR, else ~/.claude/skyops-knowledge/.
// Machine-local on purpose — lessons carry client repo internals and must not
// be committed into the published SkyOps repo. Sharing is opt-in, per lesson,
// via /sky-lesson-export.
//
// Any error => stay silent and allow (exit 0). A recall bug must never block
// or pollute a session.
//
// skyops-lint: parity-exempt — this file is intentionally larger than
// knowledge-recall.sh. The scoring half is behaviour-identical; the extra size
// is the --reindex/--list/--stats CLI, which the hot-path hook does not need.

"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");

const STORE =
  process.env.SKYOPS_KNOWLEDGE_DIR ||
  path.join(os.homedir(), ".claude", "skyops-knowledge");
const LESSONS = path.join(STORE, "lessons");

// Injection budget. Recall runs on every prompt, so it has to stay cheap:
// a weak match costs tokens forever and teaches the user to ignore the block.
const MIN_SCORE = 2; // below this, say nothing at all
const MAX_HITS = 3; // never inject more than 3 lessons
const MIN_PROMPT_LEN = 12; // "yes", "go on", "/clear" — nothing to match

// ---------------------------------------------------------------- utilities

function readLesson(file) {
  const raw = fs.readFileSync(file, "utf8");
  const m = raw.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
  if (!m) return null;
  const meta = parseFrontmatter(m[1]);
  if (!meta.id) meta.id = path.basename(file, ".md");
  meta.body = m[2].trim();
  meta.file = file;
  return meta;
}

// Minimal YAML subset: scalars, inline [a, b] arrays, and block "- item" lists.
// Deliberately not a YAML parser — the lesson format is ours and stays simple.
function parseFrontmatter(text) {
  const out = {};
  let key = null;
  for (const line of text.split(/\r?\n/)) {
    if (!line.trim() || /^\s*#/.test(line)) continue;
    const block = line.match(/^\s*-\s+(.*)$/);
    if (block && key) {
      if (!Array.isArray(out[key])) out[key] = [];
      out[key].push(strip(block[1]));
      continue;
    }
    const kv = line.match(/^([A-Za-z_][\w-]*):\s*(.*)$/);
    if (!kv) continue;
    key = kv[1];
    const val = kv[2].trim();
    if (val === "") {
      out[key] = [];
    } else if (/^\[.*\]$/.test(val)) {
      out[key] = val
        .slice(1, -1)
        .split(",")
        .map(strip)
        .filter(Boolean);
    } else {
      out[key] = strip(val);
    }
  }
  return out;
}

function strip(s) {
  return String(s).trim().replace(/^["']|["']$/g, "");
}

function loadAll() {
  if (!fs.existsSync(LESSONS)) return [];
  return fs
    .readdirSync(LESSONS)
    .filter((f) => f.endsWith(".md"))
    .map((f) => {
      try {
        return readLesson(path.join(LESSONS, f));
      } catch (_) {
        return null;
      }
    })
    .filter((l) => l && l.status !== "retired");
}

function asList(v) {
  if (!v) return [];
  return Array.isArray(v) ? v : [v];
}

// ------------------------------------------------------------------ scoring

// A lesson earns its injection or it stays quiet. Trigger keywords are the
// base signal; an SRV code, a repo name, or a real filename in the prompt are
// much stronger evidence that this lesson is actually about the task at hand.
function score(lesson, prompt) {
  const p = " " + prompt.toLowerCase().replace(/[^a-z0-9._/-]+/g, " ") + " ";
  let s = 0;
  const why = [];

  for (const t of asList(lesson.triggers)) {
    const k = String(t).toLowerCase().trim();
    if (k.length < 3) continue;
    // Also try the spaced form: a trigger written `ignore-alert` must still
    // match a prompt that says "ignore alert", which is how people type it.
    const spaced = k.replace(/-/g, " ");
    if (
      p.includes(" " + k + " ") ||
      p.includes("/" + k) ||
      p.includes(k + ".") ||
      (spaced !== k && p.includes(" " + spaced + " "))
    ) {
      // Specificity is confidence. A long trigger is a real identifier
      // (socalertsdtovalidator, createprojectscope) and is strong evidence on
      // its own; a short one (alerts, pill) could be incidental, so it needs
      // corroboration to clear MIN_SCORE.
      s += k.length >= 12 ? 2 : 1;
      why.push(k);
    }
  }

  if (lesson.srv && p.includes(String(lesson.srv).toLowerCase())) {
    s += 3;
    why.push(lesson.srv);
  }

  if (lesson.repo && p.includes(String(lesson.repo).toLowerCase())) s += 1;

  for (const f of asList(lesson.files)) {
    const base = path.basename(String(f).split(":")[0]).toLowerCase();
    if (base.length > 4 && p.includes(base)) {
      s += 2;
      why.push(base);
    }
  }

  // A lesson that keeps recurring is more likely to matter again, but this
  // only ever breaks ties — it can never carry a lesson over MIN_SCORE alone.
  if (Number(lesson.hits) >= 3 && s > 0) s += 0.5;

  return { score: s, why: [...new Set(why)].slice(0, 4) };
}

// -------------------------------------------------------------------- index

function reindex() {
  const lessons = loadAll();
  fs.mkdirSync(STORE, { recursive: true });

  const slim = lessons.map((l) => ({
    id: l.id,
    title: l.title || l.id,
    type: l.type || "fix",
    srv: l.srv || "",
    repo: l.repo || "",
    hits: Number(l.hits) || 1,
    triggers: asList(l.triggers),
    files: asList(l.files),
    status: l.status || "active",
  }));
  fs.writeFileSync(
    path.join(STORE, "index.json"),
    JSON.stringify(slim, null, 0),
    "utf8"
  );

  // index.rec is the hot-path artifact: knowledge-recall.sh reads this one file
  // with builtin reads and zero subprocess spawns. node costs ~9s to start on
  // this machine, so the per-prompt hook must never invoke it — only --reindex
  // does, and that runs once per saved lesson.
  //
  // Fields are separated by US (0x1F), not tab. Tab is IFS *whitespace*, so
  // bash's `read` collapses a run of tabs into one delimiter — an empty field
  // (a lesson with no `srv`, which is explicitly allowed) would silently shift
  // every field after it. A non-whitespace separator preserves empty fields.
  const SEP = "\x1f";
  const tsv = lessons
    .map((l) => {
      const clean = (s) =>
        String(s == null ? "" : s).replace(/[\t\r\n\x1f]+/g, " ").trim();
      const apply =
        (l.body || "")
          .split(/\r?\n/)
          .find((x) => /^\s*\*\*(Fix|Apply when)/i.test(x)) || "";
      return [
        clean(l.id),
        String(Number(l.hits) || 1),
        clean(l.srv).toLowerCase(),
        clean(l.repo).toLowerCase(),
        clean(l.title || l.id),
        asList(l.triggers).map((t) => clean(t).toLowerCase()).join(","),
        asList(l.files)
          .map((f) => path.basename(String(f).split(":")[0]).toLowerCase())
          .filter((b) => b.length > 4)
          .join(","),
        asList(l.files).slice(0, 2).map(clean).join(", "),
        clean(apply.replace(/\*\*/g, "")),
      ].join(SEP);
    })
    .join("\n");
  fs.writeFileSync(path.join(STORE, "index.rec"), tsv + (tsv ? "\n" : ""), "utf8");

  const rows = slim
    .slice()
    .sort((a, b) => b.hits - a.hits || a.id.localeCompare(b.id))
    .map(
      (l) =>
        `| ${l.id} | ${l.type} | ${l.srv || "-"} | ${l.repo || "-"} | ${l.hits} | ${l.title} |`
    );

  const md = [
    "# SkyOps lesson index",
    "",
    "Generated by `knowledge-recall.js --reindex`. Do not edit by hand.",
    "",
    `${slim.length} active lesson(s).`,
    "",
    "| id | type | SRV | repo | hits | title |",
    "|---|---|---|---|---|---|",
    ...rows,
    "",
  ].join("\n");
  fs.writeFileSync(path.join(STORE, "INDEX.md"), md, "utf8");

  const hot = slim.filter((l) => l.hits >= 3 && l.status === "active");
  process.stdout.write(
    `Reindexed ${slim.length} lesson(s) -> ${path.join(STORE, "INDEX.md")}\n`
  );
  if (hot.length) {
    process.stdout.write(
      `\n${hot.length} lesson(s) at hits>=3 and still active — candidates for promotion:\n` +
        hot.map((l) => `  - ${l.id} (${l.hits}x) ${l.title}`).join("\n") +
        "\n"
    );
  }
}

function stats() {
  const lessons = loadAll();
  const bySrv = {};
  for (const l of lessons) {
    const k = l.srv || "(not catalogued)";
    bySrv[k] = (bySrv[k] || 0) + (Number(l.hits) || 1);
  }
  const rows = Object.entries(bySrv).sort((a, b) => b[1] - a[1]);
  process.stdout.write(
    `${lessons.length} lesson(s), ${rows.length} distinct SRV bucket(s)\n\n` +
      rows.map(([k, v]) => `  ${String(v).padStart(3)}x  ${k}`).join("\n") +
      "\n"
  );
}

// --------------------------------------------------------------------- hook

function runHook() {
  // If the faster knowledge-recall.sh is already wired for this event, Claude
  // Code runs it too — stand down rather than injecting the same lessons twice.
  // Any doubt => run (see hook-env.js). SKYOPS_HOOK_IMPL=node forces node.
  try {
    if (require("./hook-env.js").wiredBashHooks("UserPromptSubmit").has("knowledge-recall.sh"))
      return quiet();
  } catch (e) {
    // hook-env missing or broken — carry on with the node implementation.
  }

  let input = "";
  process.stdin.on("data", (c) => (input += c));
  process.stdin.on("end", () => {
    try {
      const data = JSON.parse(input || "{}");
      const prompt = String(data.prompt || "");

      // Grouping key + size only. The slash-command NAME is recorded (it is an
      // identifier, e.g. "sky-review"); the prompt text never is.
      try {
        const metrics = require("./metrics.js");
        const cmd = prompt.trim().match(/^\/([a-z0-9-]{1,40})\b/i);
        metrics.record({
          kind: "prompt",
          event: "UserPromptSubmit",
          command: cmd ? cmd[1] : "none",
          prompt_bytes: metrics.bytes(prompt),
        });
      } catch (e) {}

      if (prompt.trim().length < MIN_PROMPT_LEN) return quiet();
      if (prompt.trim().startsWith("/sky-recall")) return quiet(); // don't double up

      const scored = loadAll()
        .map((l) => ({ lesson: l, ...score(l, prompt) }))
        .filter((r) => r.score >= MIN_SCORE)
        .sort((a, b) => b.score - a.score)
        .slice(0, MAX_HITS);

      if (!scored.length) return quiet();

      const lines = [
        "SkyOps recall — saved lesson(s) matching this request. Treat as a prior",
        "observation to verify, not as current truth. Check the cited file before acting.",
        "",
      ];
      for (const { lesson, why } of scored) {
        const files = asList(lesson.files).slice(0, 2).join(", ");
        lines.push(
          `- ${lesson.title || lesson.id}` +
            (lesson.srv ? ` [${lesson.srv}]` : "") +
            (Number(lesson.hits) >= 2 ? ` (seen ${lesson.hits}x)` : "")
        );
        if (files) lines.push(`  where: ${files}`);
        const apply = (lesson.body || "")
          .split(/\r?\n/)
          .find((l) => /^\s*\*\*(Fix|Apply when)/i.test(l));
        if (apply) lines.push(`  ${apply.replace(/\*\*/g, "").trim()}`);
        lines.push(`  matched: ${why.join(", ")} | id: ${lesson.id}`);
      }

      process.stdout.write(
        JSON.stringify({
          hookSpecificOutput: {
            hookEventName: "UserPromptSubmit",
            additionalContext: lines.join("\n"),
          },
        })
      );
      process.exit(0);
    } catch (_) {
      quiet();
    }
  });
}

function quiet() {
  process.exit(0);
}

// --------------------------------------------------------------------- main

try {
  const arg = process.argv[2];
  if (arg === "--reindex") reindex();
  else if (arg === "--stats") stats();
  else if (arg === "--list") {
    const f = path.join(STORE, "INDEX.md");
    process.stdout.write(
      fs.existsSync(f) ? fs.readFileSync(f, "utf8") : "No index yet — run --reindex.\n"
    );
  } else runHook();
} catch (_) {
  quiet();
}
