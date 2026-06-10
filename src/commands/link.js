const path = require("path");
const fs = require("fs");
const log = require("../lib/logger");
const { getTemplatesGithubPath, getTargetGithubPath } = require("../lib/paths");
const {
  exists,
  ensureDir,
  backupExisting,
  isSymlinkOrJunction,
  linkDirectory,
  linkFile
} = require("../lib/fs-utils");

const ITEMS = [
  "copilot-instructions.md",
  "instructions",
  "prompts",
  "skills"
];

async function link(options) {
  const templatesGithub = getTemplatesGithubPath(options.source);
  const targetGithub = getTargetGithubPath(options.target);

  log.info(`Linking CopilotOps into: ${options.target}`);
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
      if (isSymlinkOrJunction(target)) {
        log.ok(`Already linked: ${target}`);
        continue;
      }

      log.warn(`Existing target found, backing up: ${target}`);
      backupExisting(target, options.dryRun);
    }

    const stat = fs.statSync(source);

    if (stat.isDirectory()) {
      log.info(`${options.dryRun ? "[dry-run] " : ""}Link dir ${target} -> ${source}`);
      linkDirectory(source, target, options.dryRun);
    } else {
      log.info(`${options.dryRun ? "[dry-run] " : ""}Link file ${target} -> ${source}`);
      linkFile(source, target, options.dryRun);
    }
  }

  log.ok("CopilotOps link complete.");
}

module.exports = { link };
