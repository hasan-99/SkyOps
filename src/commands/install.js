const path = require("path");
const log = require("../lib/logger");
const { link } = require("./link");
const { health } = require("./health");
const { exists } = require("../lib/fs-utils");
const { getTemplatesGithubPath } = require("../lib/paths");

async function install(options) {
  const target = path.resolve(options.target);
  const source = path.resolve(options.source);
  const templatesGithub = getTemplatesGithubPath(source);

  console.log("# CopilotOps Install");
  console.log("");
  console.log(`Source: ${source}`);
  console.log(`Target: ${target}`);
  console.log(`Mode: ${options.dryRun ? "dry-run" : "apply"}`);
  console.log("");

  if (!exists(target)) {
    throw new Error(`Target project does not exist: ${target}`);
  }

  if (!exists(templatesGithub)) {
    throw new Error(`CopilotOps templates not found: ${templatesGithub}`);
  }

  log.info("Installing CopilotOps using safe linking.");
  log.info("Only Copilot-specific .github assets are linked:");
  log.info("- .github/copilot-instructions.md");
  log.info("- .github/instructions");
  log.info("- .github/prompts");
  log.info("- .github/skills");
  log.info("Project .github/workflows is not touched.");
  console.log("");

  await link(options);

  console.log("");

  if (options.dryRun) {
    log.ok("Dry-run complete. No files were changed.");
    log.info("Run again without --dry-run to apply.");
    return;
  }

  log.info("Running health check after install...");
  console.log("");

  await health(options);

  console.log("");
  log.ok("CopilotOps install complete.");
  log.info("Next: open GitHub Copilot in the target project and test /status-line, /sky-health, and /sky-task.");
}

module.exports = { install };
