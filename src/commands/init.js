const path = require("path");
const log = require("../lib/logger");
const { getTemplatesGithubPath, getTargetGithubPath } = require("../lib/paths");
const { exists, ensureDir, copyRecursive, backupExisting } = require("../lib/fs-utils");

const ITEMS = [
  "copilot-instructions.md",
  "instructions",
  "prompts",
  "skills"
];

async function init(options) {
  const templatesGithub = getTemplatesGithubPath(options.source);
  const targetGithub = getTargetGithubPath(options.target);

  log.info(`Initializing CopilotOps in: ${options.target}`);
  log.info(`Using templates from: ${templatesGithub}`);

  if (!exists(templatesGithub)) {
    throw new Error(`Templates not found: ${templatesGithub}`);
  }

  ensureDir(targetGithub, options.dryRun);

  for (const item of ITEMS) {
    const source = path.join(templatesGithub, item);
    const target = path.join(targetGithub, item);

    if (!exists(source)) {
      log.warn(`Template missing, skipping: ${item}`);
      continue;
    }

    if (exists(target)) {
      log.warn(`Existing target found, backing up: ${target}`);
      backupExisting(target, options.dryRun);
    }

    log.info(`${options.dryRun ? "[dry-run] " : ""}Copy ${source} -> ${target}`);
    copyRecursive(source, target, options.dryRun);
  }

  log.ok("CopilotOps init complete.");
}

module.exports = { init };
