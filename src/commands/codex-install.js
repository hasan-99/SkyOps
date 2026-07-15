const fs = require("fs");
const path = require("path");
const log = require("../lib/logger");
const { exists, ensureDir, copyRecursive, backupExisting } = require("../lib/fs-utils");
const { getTemplatesGithubPath } = require("../lib/paths");

function defaultCodexHome() {
  if (process.env.CODEX_HOME) {
    return process.env.CODEX_HOME;
  }

  if (process.env.USERPROFILE) {
    return path.join(process.env.USERPROFILE, ".codex");
  }

  if (process.env.HOME) {
    return path.join(process.env.HOME, ".codex");
  }

  throw new Error("Could not find Codex home. Set CODEX_HOME or pass --codex-home <path>.");
}

function parseFrontmatter(content, fallbackName) {
  const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?/);
  const body = match ? content.slice(match[0].length) : content;
  const frontmatter = match ? match[1] : "";

  const nameMatch = frontmatter.match(/^name:\s*(.+)$/m);
  const descriptionMatch = frontmatter.match(/^description:\s*(.+)$/m);

  return {
    name: nameMatch ? nameMatch[1].trim().replace(/^["']|["']$/g, "") : fallbackName,
    description: descriptionMatch
      ? descriptionMatch[1].trim().replace(/^["']|["']$/g, "")
      : `Codex skill converted from the ${fallbackName} CopilotOps agent.`,
    body
  };
}

function writeConvertedAgentSkill(sourceFile, targetDir, dryRun) {
  const fallbackName = path.basename(sourceFile, ".agent.md");
  const content = fs.readFileSync(sourceFile, "utf8");
  const parsed = parseFrontmatter(content, fallbackName);
  const skillContent = `---\nname: ${parsed.name}\ndescription: ${parsed.description}\n---\n\n${parsed.body}`;

  if (dryRun) {
    return;
  }

  ensureDir(targetDir, false);
  fs.writeFileSync(path.join(targetDir, "SKILL.md"), skillContent, "utf8");
}

function prepareTarget(target, options) {
  if (!exists(target)) {
    return true;
  }

  if (!options.force) {
    log.warn(`Existing Codex skill found, skipping: ${target}`);
    return false;
  }

  log.warn(`Existing Codex skill found, backing up: ${target}`);
  backupExisting(target, options.dryRun);
  return true;
}

async function codexInstall(options) {
  const source = path.resolve(options.source);
  const templatesGithub = getTemplatesGithubPath(source);
  const templateSkills = path.join(templatesGithub, "skills");
  const templateAgents = path.join(templatesGithub, "agents");
  const codexHome = path.resolve(options.codexHome || defaultCodexHome());
  const codexSkills = path.join(codexHome, "skills");
  const copiedSkillNames = new Set();

  console.log("# CopilotOps Codex Install");
  console.log("");
  console.log(`Source: ${source}`);
  console.log(`Codex home: ${codexHome}`);
  console.log(`Codex skills: ${codexSkills}`);
  console.log(`Mode: ${options.dryRun ? "dry-run" : "apply"}`);
  console.log("");

  if (!exists(templatesGithub)) {
    throw new Error(`CopilotOps templates not found: ${templatesGithub}`);
  }

  if (!exists(templateSkills) && !exists(templateAgents)) {
    throw new Error(`No CopilotOps skills or agents found under: ${templatesGithub}`);
  }

  ensureDir(codexSkills, options.dryRun);

  if (exists(templateSkills)) {
    for (const item of fs.readdirSync(templateSkills)) {
      const sourceSkill = path.join(templateSkills, item);

      if (!fs.statSync(sourceSkill).isDirectory()) {
        continue;
      }

      const targetSkill = path.join(codexSkills, item);
      copiedSkillNames.add(item);

      if (!prepareTarget(targetSkill, options)) {
        continue;
      }

      log.info(`${options.dryRun ? "[dry-run] " : ""}Copy skill ${sourceSkill} -> ${targetSkill}`);
      copyRecursive(sourceSkill, targetSkill, options.dryRun);
    }
  }

  if (exists(templateAgents)) {
    for (const item of fs.readdirSync(templateAgents)) {
      if (!item.endsWith(".agent.md")) {
        continue;
      }

      const sourceAgent = path.join(templateAgents, item);
      const fallbackName = path.basename(item, ".agent.md");

      if (copiedSkillNames.has(fallbackName)) {
        log.info(`Codex skill already provided by templates/.github/skills, skipping agent: ${fallbackName}`);
        continue;
      }

      const targetSkill = path.join(codexSkills, fallbackName);

      if (!prepareTarget(targetSkill, options)) {
        continue;
      }

      log.info(`${options.dryRun ? "[dry-run] " : ""}Convert agent ${sourceAgent} -> ${targetSkill}\\SKILL.md`);
      writeConvertedAgentSkill(sourceAgent, targetSkill, options.dryRun);
    }
  }

  console.log("");

  if (options.dryRun) {
    log.ok("Codex dry-run complete. No files were changed.");
    log.info("Run again without --dry-run to copy skills into Codex.");
    return;
  }

  log.ok("CopilotOps Codex install complete.");
  log.info("Restart/open a new Codex session so the newly installed skills are discovered.");
  log.info("Use them by name, for example: use $status-line or use $sky-task to plan this backend change.");
}

module.exports = { codexInstall };
