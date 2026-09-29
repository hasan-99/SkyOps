#!/usr/bin/env node
// SkyOps vault sync — keeps SkyOps/ (the Obsidian vault) from drifting away from the real
// commands/, skills/, and agents/ frontmatter, and regenerates the
// derived Canvas map from whatever [[wikilinks]] actually exist in the vault.
//
// What it does NOT do: it never touches hand-authored prose. Every vault
// note gets one small machine-owned block between
//   <!-- sky-sync:start --> ... <!-- sky-sync:end -->
// which is fully replaced on each run. Everything outside that block is
// left exactly as written. If a command/skill/agent has no matching vault
// note at all, a minimal stub is created (frontmatter + sync block +
// TODO) — it still needs a human pass to write the real content.
//
// Three Canvas boards, all fully derived from the vault's own wikilinks and
// frontmatter `type:` (always fully regenerated, never hand-edited):
//   - "SkyOps Map.canvas"              every note, as a directory — ZERO
//                                       edges on purpose, see the code comment
//                                       on generateMainCanvas() for why.
//   - "Review Pipeline Map.canvas"     sky-review's 1-hop neighborhood only.
//   - "Skills and Agents Map.canvas"   skill<->agent cross-links only.
// Same sync treatment for the Changelog note's version table, from CHANGELOG.md.
//
// Every run also checks every [[wikilink]] in the vault against every real
// note/canvas file and reports any that don't resolve (read-only, never
// fixes them — a broken link is a signal something needs a human decision).
// The process exits non-zero if any are found, so this can gate CI.
//
// Usage:
//   node scripts/sky-generate-vault.js            sync notes + rebuild canvas + link check
//   node scripts/sky-generate-vault.js --dry-run   report only, write nothing
//   node scripts/sky-generate-vault.js --canvas-only   skip note/changelog sync
//
// Self-test: node scripts/sky-generate-vault.js --selftest

"use strict";

const fs = require("fs");
const path = require("path");

const REPO_ROOT = path.join(__dirname, "..");
const VAULT_ROOT = path.join(REPO_ROOT, "SkyOps");
const AUTHOR = "Hasan Jahouse";

const SYNC_START = "<!-- sky-sync:start -->";
const SYNC_END = "<!-- sky-sync:end -->";

// ---------------------------------------------------------------------------
// Frontmatter helpers
// ---------------------------------------------------------------------------

function parseFrontmatter(content) {
  const m = content.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n/);
  if (!m) return { fields: {}, blockLength: 0 };
  const fields = {};
  for (const line of m[1].split(/\r?\n/)) {
    const kv = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (kv) fields[kv[1]] = kv[2].trim();
  }
  return { fields, blockLength: m[0].length };
}

function listMdFiles(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir).filter((f) => f.endsWith(".md"));
}

// ---------------------------------------------------------------------------
// Step 1 — discover the real repo surface
// ---------------------------------------------------------------------------

function discoverCommands() {
  const dir = path.join(REPO_ROOT, "commands");
  return listMdFiles(dir).map((f) => {
    const name = f.replace(/\.md$/, "");
    const content = fs.readFileSync(path.join(dir, f), "utf8");
    const { fields } = parseFrontmatter(content);
    return { kind: "command", name, sourcePath: `commands/${f}`, fields };
  });
}

function discoverSkills() {
  const dir = path.join(REPO_ROOT, "skills");
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir)
    .filter((d) => fs.statSync(path.join(dir, d)).isDirectory())
    .map((name) => {
      const skillFile = path.join(dir, name, "SKILL.md");
      if (!fs.existsSync(skillFile)) return null;
      const content = fs.readFileSync(skillFile, "utf8");
      const { fields } = parseFrontmatter(content);
      return { kind: "skill", name, sourcePath: `skills/${name}/SKILL.md`, fields };
    })
    .filter(Boolean);
}

function discoverAgents() {
  const dir = path.join(REPO_ROOT, "agents");
  return listMdFiles(dir).map((f) => {
    const name = f.replace(/\.md$/, "");
    const content = fs.readFileSync(path.join(dir, f), "utf8");
    const { fields } = parseFrontmatter(content);
    return { kind: "agent", name, sourcePath: `agents/${f}`, fields };
  });
}

// ---------------------------------------------------------------------------
// Step 2 — find (or place) the matching vault note
// ---------------------------------------------------------------------------

function walkVaultFiles(extensions) {
  const results = [];
  function walk(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (entry.name === ".obsidian") continue;
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (extensions.some((ext) => entry.name.endsWith(ext))) results.push(full);
    }
  }
  walk(VAULT_ROOT);
  return results;
}

function walkVaultNotes() {
  const results = [];
  function walk(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (entry.name === ".obsidian") continue;
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (entry.name.endsWith(".md")) results.push(full);
    }
  }
  walk(VAULT_ROOT);
  return results;
}

const DEFAULT_FOLDER = {
  command: "01 Commands",
  skill: "02 Skills",
  agent: "03 Agents",
};

function findVaultNoteFor(name, existingNotes) {
  return existingNotes.find((p) => path.basename(p, ".md") === name) || null;
}

// ---------------------------------------------------------------------------
// Step 3 — build and upsert the sync block
// ---------------------------------------------------------------------------

function buildSyncBlock(item) {
  const lines = [SYNC_START, `**Repo source:** \`${item.sourcePath}\``];
  if (item.fields.description) {
    lines.push(`**Repo description:** ${item.fields.description}`);
  }
  if (item.kind === "command") {
    lines.push(
      `**user-invocable:** ${item.fields["user-invocable"] ?? "?"} · **disable-model-invocation:** ${
        item.fields["disable-model-invocation"] ?? "?"
      }`
    );
  } else if (item.kind === "skill") {
    lines.push(
      `**user-invocable:** ${item.fields["user-invocable"] ?? "?"} · **disable-model-invocation:** ${
        item.fields["disable-model-invocation"] ?? "?"
      }`
    );
  } else if (item.kind === "agent") {
    if (item.fields.model) lines.push(`**model:** ${item.fields.model}`);
    if (item.fields.tools) lines.push(`**tools:** ${item.fields.tools}`);
  }
  lines.push(
    `*Synced ${new Date().toISOString().slice(0, 10)} by \`scripts/sky-generate-vault.js\` — hand-authored content below this block is preserved on re-run.*`
  );
  lines.push(SYNC_END);
  return lines.join("\n");
}

function upsertSyncBlock(content, block) {
  const re = new RegExp(`${SYNC_START}[\\s\\S]*?${SYNC_END}`);
  if (re.test(content)) return content.replace(re, block);
  const fm = content.match(/^---\r?\n[\s\S]*?\r?\n---\r?\n/);
  if (fm) {
    const idx = fm[0].length;
    return content.slice(0, idx) + "\n" + block + "\n" + content.slice(idx);
  }
  return block + "\n\n" + content;
}

function stubNote(item) {
  const block = buildSyncBlock(item);
  return [
    "---",
    `type: ${item.kind}`,
    `tags: [${item.kind}, skyops]`,
    `author: ${AUTHOR}`,
    "version: 1.0",
    "---",
    "",
    block,
    "",
    `# ${item.name}`,
    "",
    "TODO: describe — auto-created stub, not yet reviewed by a human.",
    "",
  ].join("\n");
}

function syncNotes({ dryRun }) {
  const items = [...discoverCommands(), ...discoverSkills(), ...discoverAgents()];
  const existingNotes = walkVaultNotes();
  let updated = 0;
  let created = 0;

  for (const item of items) {
    const notePath = findVaultNoteFor(item.name, existingNotes);
    const block = buildSyncBlock(item);

    if (!notePath) {
      const target = path.join(VAULT_ROOT, DEFAULT_FOLDER[item.kind], `${item.name}.md`);
      console.log(`[stub]   ${item.kind.padEnd(7)} ${item.name} — no vault note found, creating ${path.relative(VAULT_ROOT, target)}`);
      if (!dryRun) fs.writeFileSync(target, stubNote(item), "utf8");
      created++;
      continue;
    }

    const content = fs.readFileSync(notePath, "utf8");
    const next = upsertSyncBlock(content, block);
    if (next !== content) {
      console.log(`[sync]   ${item.kind.padEnd(7)} ${item.name} — ${path.relative(VAULT_ROOT, notePath)}`);
      if (!dryRun) fs.writeFileSync(notePath, next, "utf8");
      updated++;
    }
  }

  console.log(`\nsyncNotes: ${items.length} repo items checked, ${updated} note(s) updated, ${created} stub(s) created.`);
}

// ---------------------------------------------------------------------------
// Step 4 — regenerate the Canvas map from the vault's own wikilinks
// ---------------------------------------------------------------------------

const TYPE_COLUMN = { moc: 0, architecture: 1, standard: 2, command: 3, skill: 4, agent: 5 };
const TYPE_COLOR = { moc: "1", architecture: "2", standard: "3", command: "4", skill: "5", agent: "6" };
const TYPE_LABEL = {
  moc: "Home",
  architecture: "Architecture",
  standard: "Standards",
  command: "Commands",
  skill: "Skills",
  agent: "Agents",
};

const COL_WIDTH = 420;
const ROW_HEIGHT = 90;
const NODE_WIDTH = 340;
const NODE_HEIGHT = 60;

function extractWikilinks(body) {
  const links = new Set();
  const re = /\[\[([^\]|#]+)(?:[|#][^\]]*)?\]\]/g;
  let m;
  while ((m = re.exec(body))) links.add(m[1].trim());
  return links;
}

function scanVault() {
  const mdFiles = walkVaultNotes();
  const canvasFiles = walkVaultFiles([".canvas"]);
  const allBasenames = new Set();
  const byBasename = new Map(); // basename -> { relPath, type } (markdown notes only)
  const parsed = [];

  for (const f of canvasFiles) allBasenames.add(path.basename(f, ".canvas"));

  for (const notePath of mdFiles) {
    const content = fs.readFileSync(notePath, "utf8");
    const { fields } = parseFrontmatter(content);
    const type = fields.type || "command";
    const basename = path.basename(notePath, ".md");
    const relPath = path.relative(VAULT_ROOT, notePath).split(path.sep).join("/");
    allBasenames.add(basename);
    byBasename.set(basename, { relPath, type });
    parsed.push({ basename, relPath, type, links: extractWikilinks(content) });
  }

  return { parsed, byBasename, allBasenames };
}

const idOf = (basename) => `n:${basename}`;

// All wikilink edges in the vault, deduped, as plain {from, to} pairs —
// independent of any one canvas's node/id layout. Shared by every board.
function computeAllEdges(scan) {
  const { parsed, byBasename } = scan;
  const edges = [];
  const seen = new Set();
  for (const { basename, links } of parsed) {
    for (const target of links) {
      if (!byBasename.has(target) || target === basename) continue;
      const key = `${basename}->${target}`;
      if (seen.has(key)) continue;
      seen.add(key);
      edges.push({ from: basename, to: target });
    }
  }
  return edges;
}

// Lays out a subset of notes in columns by type (re-indexed to consecutive
// columns so a 2-type board doesn't leave empty columns), and turns a subset
// of {from, to} edges into canvas edges — silently drops any edge whose
// endpoint isn't in this board's node subset.
function buildCanvasBoard(nodesSubset, edgesSubset) {
  const typesPresent = Object.keys(TYPE_COLUMN)
    .filter((t) => nodesSubset.some((n) => n.type === t))
    .sort((a, b) => TYPE_COLUMN[a] - TYPE_COLUMN[b]);
  const localCol = new Map(typesPresent.map((t, i) => [t, i]));

  const columnCounts = {};
  const nodeIds = new Set(nodesSubset.map((n) => n.basename));
  const nodes = [];

  for (const { basename, relPath, type } of nodesSubset) {
    const col = localCol.get(type) ?? 0;
    const row = columnCounts[col] || 0;
    columnCounts[col] = row + 1;
    nodes.push({
      id: idOf(basename),
      type: "file",
      file: relPath,
      x: col * COL_WIDTH,
      y: row * ROW_HEIGHT,
      width: NODE_WIDTH,
      height: NODE_HEIGHT,
      color: TYPE_COLOR[type] || "4",
    });
  }

  const groups = typesPresent.map((type) => {
    const col = localCol.get(type);
    return {
      id: `g:${type}`,
      type: "group",
      label: TYPE_LABEL[type],
      x: col * COL_WIDTH - 20,
      y: -110,
      width: NODE_WIDTH + 40,
      height: (columnCounts[col] || 1) * ROW_HEIGHT + 150,
    };
  });

  const edges = edgesSubset
    .filter((e) => nodeIds.has(e.from) && nodeIds.has(e.to))
    .map((e) => ({
      id: `e:${e.from}:${e.to}`,
      fromNode: idOf(e.from),
      fromSide: "right",
      toNode: idOf(e.to),
      toSide: "left",
    }));

  return { nodes: [...groups, ...nodes], edges };
}

function writeCanvas(name, canvas, dryRun) {
  const outPath = path.join(VAULT_ROOT, `${name}.canvas`);
  const fileNodeCount = canvas.nodes.filter((n) => n.type === "file").length;
  console.log(`generateCanvas: ${name} — ${fileNodeCount} notes, ${canvas.edges.length} edges`);
  if (!dryRun) fs.writeFileSync(outPath, JSON.stringify(canvas, null, 2), "utf8");
}

// Main board: every note, laid out as a clean directory — deliberately
// ZERO edges. 423+ wikilink edges on one board is unreadable regardless of
// layout; that job belongs to the Graph view (dynamic, filterable) and the
// two focused boards below (curated, low-count). Two extra nodes point at
// those boards so the main map is still the natural starting point.
function generateMainCanvas({ dryRun }, scan) {
  const { parsed } = scan;
  const board = buildCanvasBoard(parsed, []);

  const maxY = Math.max(60, ...board.nodes.filter((n) => n.type === "file").map((n) => n.y + NODE_HEIGHT));
  board.nodes.push(
    {
      id: "n:__note",
      type: "text",
      text: "This board is a directory, not a link map — it has no connection lines on purpose (423+ wikilinks on one board is unreadable). Open a note to see its links in the Backlinks/Outgoing panes, or use Graph view for the full web. For curated, low-count connection views, open the two boards below.",
      x: 0,
      y: maxY + 60,
      width: NODE_WIDTH * 2 + COL_WIDTH,
      height: 100,
    },
    {
      id: "n:__link_review",
      type: "file",
      file: "Review Pipeline Map.canvas",
      x: 0,
      y: maxY + 190,
      width: NODE_WIDTH,
      height: NODE_HEIGHT,
      color: "2",
    },
    {
      id: "n:__link_skillsagents",
      type: "file",
      file: "Skills and Agents Map.canvas",
      x: COL_WIDTH,
      y: maxY + 190,
      width: NODE_WIDTH,
      height: NODE_HEIGHT,
      color: "2",
    }
  );

  writeCanvas("SkyOps Map", board, dryRun);
}

// Focused board 1: a hub-and-spoke star around sky-review — sky-review
// itself plus everything one hop away in either direction (its internal
// skills, the review-lane agents, sky-scope), with edges kept to ONLY those
// that touch sky-review directly. Neighbors are frequently cross-linked
// with each other too (e.g. every review-lane agent links to SRV Catalog),
// so including those inter-neighbor edges would just reproduce the same
// density problem at a smaller scale — the star stays readable because it
// can never have more edges than nodes.
function generateReviewPipelineCanvas({ dryRun }, scan, allEdges) {
  const { parsed } = scan;
  const neighbors = new Set(["sky-review"]);
  const edgesSubset = [];
  for (const e of allEdges) {
    if (e.from === "sky-review") {
      neighbors.add(e.to);
      edgesSubset.push(e);
    } else if (e.to === "sky-review") {
      neighbors.add(e.from);
      edgesSubset.push(e);
    }
  }
  const nodesSubset = parsed.filter((n) => neighbors.has(n.basename));
  writeCanvas("Review Pipeline Map", buildCanvasBoard(nodesSubset, edgesSubset), dryRun);
}

// Focused board 2: skill <-> agent cross-links only (the plan-stage skill
// to review-time agent counterpart pairs, plus any other skill/agent
// references) — every command/architecture link is dropped, so this stays
// small no matter how the vault grows.
function generateSkillsAgentsCanvas({ dryRun }, scan, allEdges) {
  const { parsed, byBasename } = scan;
  const nodesSubset = parsed.filter((n) => n.type === "skill" || n.type === "agent");
  const edgesSubset = allEdges.filter((e) => {
    const a = byBasename.get(e.from);
    const b = byBasename.get(e.to);
    return a && b && (a.type === "skill" || a.type === "agent") && (b.type === "skill" || b.type === "agent");
  });
  writeCanvas("Skills and Agents Map", buildCanvasBoard(nodesSubset, edgesSubset), dryRun);
}

// ---------------------------------------------------------------------------
// Step 5 — broken-link check (read-only, never writes)
// ---------------------------------------------------------------------------

function checkBrokenLinks(scan) {
  const { parsed, allBasenames } = scan;
  const broken = [];
  for (const { basename, relPath, links } of parsed) {
    for (const target of links) {
      if (target === basename) continue;
      if (!allBasenames.has(target)) broken.push({ from: relPath, target });
    }
  }
  if (broken.length === 0) {
    console.log(`\ncheckBrokenLinks: 0 broken links across ${parsed.length} notes.`);
  } else {
    console.log(`\ncheckBrokenLinks: ${broken.length} broken link(s):`);
    for (const b of broken) console.log(`  [broken] ${b.from} -> [[${b.target}]]`);
  }
  return broken;
}

// ---------------------------------------------------------------------------
// Step 6 — sync the Changelog note's version index from CHANGELOG.md
// ---------------------------------------------------------------------------

function generateChangelogNote({ dryRun }) {
  const changelogPath = path.join(REPO_ROOT, "CHANGELOG.md");
  if (!fs.existsSync(changelogPath)) return;
  const content = fs.readFileSync(changelogPath, "utf8");
  const re = /^## \[([^\]]+)\] - (.+)$/gm;
  const rows = [];
  let m;
  while ((m = re.exec(content))) rows.push({ version: m[1], title: m[2].trim() });

  const block = [
    SYNC_START,
    "**Repo source:** `CHANGELOG.md`",
    "",
    "| Version | Title |",
    "|---|---|",
    ...rows.map((r) => `| ${r.version} | ${r.title} |`),
    "",
    `*Synced ${new Date().toISOString().slice(0, 10)} by \`scripts/sky-generate-vault.js\` from ${rows.length} version header(s) in CHANGELOG.md — hand-authored content below this block is preserved on re-run.*`,
    SYNC_END,
  ].join("\n");

  const target = path.join(VAULT_ROOT, "00 Architecture", "Changelog.md");
  const existing = fs.existsSync(target)
    ? fs.readFileSync(target, "utf8")
    : [
        "---",
        "type: architecture",
        "tags: [architecture, skyops, changelog]",
        `author: ${AUTHOR}`,
        "version: 1.0",
        "---",
        "",
        "# Changelog",
        "",
        "Full entries (what changed and why, per version) live in the canonical `CHANGELOG.md` at the repo root — this note is a synced index, not a copy, so it never drifts.",
        "",
        "## See also",
        "",
        "[[Repo Overview]]",
        "",
      ].join("\n");

  const next = upsertSyncBlock(existing, block);
  console.log(`\ngenerateChangelogNote: ${rows.length} version(s) synced -> 00 Architecture/Changelog.md`);
  if (!dryRun) fs.writeFileSync(target, next, "utf8");
}

// ---------------------------------------------------------------------------
// Self-test — sanity check the frontmatter parser and wikilink extractor
// ---------------------------------------------------------------------------

function selfTest() {
  const fm = parseFrontmatter("---\nname: foo\ndescription: bar baz\n---\nbody");
  console.assert(fm.fields.name === "foo", "frontmatter name parse failed");
  console.assert(fm.fields.description === "bar baz", "frontmatter description parse failed");

  const links = extractWikilinks("See [[Home]] and [[sky-review|the reviewer]] and [[SRV Catalog#anchor]].");
  console.assert(links.has("Home"), "plain wikilink not extracted");
  console.assert(links.has("sky-review"), "aliased wikilink not extracted");
  console.assert(links.has("SRV Catalog"), "anchored wikilink not extracted");

  console.log("selftest: ok");
}

// ---------------------------------------------------------------------------

function main() {
  const args = process.argv.slice(2);
  if (args.includes("--selftest")) return selfTest();

  const dryRun = args.includes("--dry-run");
  const canvasOnly = args.includes("--canvas-only");

  if (!fs.existsSync(VAULT_ROOT)) {
    console.error(`No vault found at ${VAULT_ROOT}`);
    process.exit(1);
  }

  if (!canvasOnly) {
    syncNotes({ dryRun });
    generateChangelogNote({ dryRun });
  }

  const scan = scanVault();
  const allEdges = computeAllEdges(scan);
  generateMainCanvas({ dryRun }, scan);
  generateReviewPipelineCanvas({ dryRun }, scan, allEdges);
  generateSkillsAgentsCanvas({ dryRun }, scan, allEdges);
  const broken = checkBrokenLinks(scan);

  if (dryRun) console.log("\n(dry run — nothing written)");
  if (broken.length > 0) process.exitCode = 1;
}

main();
