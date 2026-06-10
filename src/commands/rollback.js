const path = require("path");
const fs = require("fs");
const log = require("../lib/logger");
const { exists, removeRecursive } = require("../lib/fs-utils");

const ITEMS = [
  "copilot-instructions.md",
  "instructions",
  "prompts",
  "skills"
];

async function rollback(options) {
  const target = path.resolve(options.target);
  const github = path.join(target, ".github");

  log.info(`Rolling back CopilotOps assets in: ${target}`);

  for (const item of ITEMS) {
    const current = path.join(github, item);
    const backup = `${current}.backup`;

    if (!exists(backup)) {
      log.warn(`No backup found for: ${item}`);
      continue;
    }

    if (exists(current)) {
      log.info(`${options.dryRun ? "[dry-run] " : ""}Remove current: ${current}`);
      removeRecursive(current, options.dryRun);
    }

    log.info(`${options.dryRun ? "[dry-run] " : ""}Restore ${backup} -> ${current}`);

    if (!options.dryRun) {
      fs.renameSync(backup, current);
    }
  }

  log.ok("Rollback complete.");
}

module.exports = { rollback };
