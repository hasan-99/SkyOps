const path = require("path");
const fs = require("fs");
const log = require("../lib/logger");
const { exists } = require("../lib/fs-utils");

function findFilesByExtension(root, extension, maxDepth = 3) {
  const results = [];

  function walk(dir, depth) {
    if (depth > maxDepth || !exists(dir)) {
      return;
    }

    for (const item of fs.readdirSync(dir)) {
      if (item === "node_modules" || item === ".git" || item === "bin" || item === "obj") {
        continue;
      }

      const full = path.join(dir, item);
      const stat = fs.statSync(full);

      if (stat.isDirectory()) {
        walk(full, depth + 1);
      } else if (item.endsWith(extension)) {
        results.push(full);
      }
    }
  }

  walk(root, 0);
  return results;
}

async function health(options) {
  const target = path.resolve(options.target);
  const github = path.join(target, ".github");

  const checks = [
    ["copilot-instructions.md", path.join(github, "copilot-instructions.md")],
    ["instructions", path.join(github, "instructions")],
    ["prompts", path.join(github, "prompts")],
    ["skills", path.join(github, "skills")]
  ];

  let failures = 0;
  let warnings = 0;

  console.log("# CopilotOps Health Report");
  console.log("");
  console.log(`Target: ${target}`);
  console.log("");

  console.log("## Copilot Assets");
  for (const [name, p] of checks) {
    if (exists(p)) {
      console.log(`- OK: ${name}`);
    } else {
      console.log(`- FAIL: ${name} missing`);
      failures++;
    }
  }

  console.log("");
  console.log("## Repository Shape");

  const slnFiles = findFilesByExtension(target, ".sln");
  const csprojFiles = findFilesByExtension(target, ".csproj");
  const workflows = path.join(github, "workflows");

  console.log(`- Solution files: ${slnFiles.length}`);
  console.log(`- C# project files: ${csprojFiles.length}`);
  console.log(`- GitHub workflows folder: ${exists(workflows) ? "present" : "not found"}`);

  if (csprojFiles.length === 0) {
    warnings++;
  }

  console.log("");
  console.log("## Overall");

  if (failures > 0) {
    console.log("Status: RED");
  } else if (warnings > 0) {
    console.log("Status: YELLOW");
  } else {
    console.log("Status: GREEN");
  }

  console.log("");
  log.ok("Health check complete.");
}

module.exports = { health };
