const path = require("path");
const fs = require("fs");
const childProcess = require("child_process");
const log = require("../lib/logger");
const { exists } = require("../lib/fs-utils");
const { getTemplatesGithubPath, getTargetGithubPath } = require("../lib/paths");

function readJson(filePath) {
  if (!exists(filePath)) {
    return null;
  }

  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch {
    return null;
  }
}

function readText(filePath) {
  if (!exists(filePath)) {
    return null;
  }

  return fs.readFileSync(filePath, "utf8").trim();
}

function tryRun(command, cwd) {
  try {
    return childProcess.execSync(command, {
      cwd,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"]
    }).trim();
  } catch {
    return null;
  }
}

function checkLinkStatus(targetPath) {
  if (!exists(targetPath)) {
    return "missing";
  }

  try {
    const stat = fs.lstatSync(targetPath);

    if (stat.isSymbolicLink()) {
      return "linked";
    }

    return "present";
  } catch {
    return "unknown";
  }
}

function getNodeMajorVersion() {
  const raw = process.version.replace(/^v/, "");
  const major = Number(raw.split(".")[0]);

  return {
    raw: process.version,
    major: Number.isFinite(major) ? major : null
  };
}

async function doctor(options) {
  const source = path.resolve(options.source);
  const target = path.resolve(options.target);
  const templatesGithub = getTemplatesGithubPath(source);
  const targetGithub = getTargetGithubPath(target);

  let failures = 0;
  let warnings = 0;

  function pass(message) {
    console.log(`- PASS: ${message}`);
  }

  function warn(message) {
    warnings++;
    console.log(`- WARN: ${message}`);
  }

  function fail(message) {
    failures++;
    console.log(`- FAIL: ${message}`);
  }

  console.log("# CopilotOps Doctor Report");
  console.log("");
  console.log(`Source: ${source}`);
  console.log(`Target: ${target}`);
  console.log("");

  console.log("## Runtime");
  const nodeVersion = getNodeMajorVersion();

  if (nodeVersion.major !== null && nodeVersion.major >= 18) {
    pass(`Node.js ${nodeVersion.raw}`);
  } else {
    fail(`Node.js ${nodeVersion.raw}; expected >= 18`);
  }

  if (process.platform === "win32") {
    warn("Windows detected. Directory links use junctions/symlinks; run dry-run before real linking.");
  } else {
    pass(`Platform: ${process.platform}`);
  }

  console.log("");
  console.log("## Framework Version");

  const packageJsonPath = path.join(source, "package.json");
  const versionPath = path.join(source, "VERSION");
  const packageJson = readJson(packageJsonPath);
  const versionText = readText(versionPath);

  if (!packageJson) {
    fail("package.json missing or invalid");
  } else {
    pass(`package.json found, version ${packageJson.version || "unknown"}`);
  }

  if (!versionText) {
    fail("VERSION file missing or empty");
  } else {
    pass(`VERSION file found, version ${versionText}`);
  }

  if (packageJson && versionText) {
    if (packageJson.version === versionText) {
      pass("package.json version matches VERSION");
    } else {
      fail(`Version mismatch: package.json=${packageJson.version}, VERSION=${versionText}`);
    }
  }

  console.log("");
  console.log("## Framework Files");

  const requiredFrameworkFiles = [
    "README.md",
    "CHANGELOG.md",
    "CONTRIBUTING.md",
    "bin/copilotops.js",
    "src/cli.js",
    "src/commands/init.js",
    "src/commands/link.js",
    "src/commands/health.js",
    "src/commands/validate.js",
    "src/commands/rollback.js",
    "src/commands/doctor.js"
  ];

  for (const file of requiredFrameworkFiles) {
    const full = path.join(source, file);

    if (exists(full)) {
      pass(file);
    } else {
      fail(`${file} missing`);
    }
  }

  console.log("");
  console.log("## Templates");

  const requiredTemplates = [
    "copilot-instructions.md",
    "instructions",
    "prompts",
    "skills"
  ];

  if (!exists(templatesGithub)) {
    fail(`templates/.github missing: ${templatesGithub}`);
  } else {
    pass("templates/.github exists");

    for (const item of requiredTemplates) {
      const full = path.join(templatesGithub, item);

      if (exists(full)) {
        pass(`templates/.github/${item}`);
      } else {
        fail(`templates/.github/${item} missing`);
      }
    }
  }

  console.log("");
  console.log("## Target Project");

  if (!exists(target)) {
    fail(`Target project does not exist: ${target}`);
  } else {
    pass("Target project exists");
  }

  if (!exists(targetGithub)) {
    warn("Target .github folder missing. Run `copilotops init` or `copilotops link` after dry-run.");
  } else {
    pass("Target .github folder exists");
  }

  const targetAssets = [
    "copilot-instructions.md",
    "instructions",
    "prompts",
    "skills"
  ];

  for (const item of targetAssets) {
    const full = path.join(targetGithub, item);
    const status = checkLinkStatus(full);

    if (status === "linked") {
      pass(`Target .github/${item} is linked`);
    } else if (status === "present") {
      warn(`Target .github/${item} exists but is not a link`);
    } else if (status === "missing") {
      warn(`Target .github/${item} missing`);
    } else {
      warn(`Target .github/${item} status unknown`);
    }
  }

  const workflowsPath = path.join(targetGithub, "workflows");

  if (exists(workflowsPath)) {
    pass("Target .github/workflows exists and should remain untouched");
  } else {
    warn("Target .github/workflows not found; this is OK if the project has no workflows");
  }

  console.log("");
  console.log("## Git");

  const gitVersion = tryRun("git --version", target);

  if (gitVersion) {
    pass(gitVersion);

    const branch = tryRun("git rev-parse --abbrev-ref HEAD", target);
    const status = tryRun("git status --short", target);

    if (branch) {
      pass(`Branch: ${branch}`);
    } else {
      warn("Could not detect git branch");
    }

    if (status === null) {
      warn("Could not read git status");
    } else if (status.length === 0) {
      pass("Git status: clean");
    } else {
      warn("Git status: changed files present");
    }
  } else {
    warn("Git not available or target is not a git repository");
  }

  console.log("");
  console.log("## Result");

  if (failures > 0) {
    console.log(`Status: RED (${failures} failures, ${warnings} warnings)`);
    console.log("Recommended next action: fix failed framework checks before linking projects.");
    process.exitCode = 1;
  } else if (warnings > 0) {
    console.log(`Status: YELLOW (${warnings} warnings)`);
    console.log("Recommended next action: review warnings, then run link with --dry-run.");
  } else {
    console.log("Status: GREEN");
    console.log("Recommended next action: run `copilotops health` or test GitHub Copilot prompts.");
  }

  console.log("");
  log.ok("Doctor check complete.");
}

module.exports = { doctor };
