const path = require("path");
const fs = require("fs");
const log = require("../lib/logger");
const { exists } = require("../lib/fs-utils");

const REQUIRED_FILES = [
  "package.json",
  "README.md",
  "VERSION",
  "CHANGELOG.md",
  "CONTRIBUTING.md",
  "src/commands/install.js",
  "src/commands/doctor.js",
  "templates/.github/copilot-instructions.md",
  "templates/.github/prompts",
  "templates/.github/skills",
  "templates/.github/instructions"
];

const PLANNING_PROMPTS = [
  "sky-task.prompt.md",
  "sky-fast.prompt.md",
  "sky-debug.prompt.md"
];

function validateVersionMatch(root) {
  const packagePath = path.join(root, "package.json");
  const versionPath = path.join(root, "VERSION");

  if (!exists(packagePath) || !exists(versionPath)) {
    return {
      ok: false,
      message: "package.json and VERSION are required for version validation."
    };
  }

  const packageJson = JSON.parse(fs.readFileSync(packagePath, "utf8"));
  const version = fs.readFileSync(versionPath, "utf8").trim();

  if (packageJson.version !== version) {
    return {
      ok: false,
      message: `package.json version (${packageJson.version}) does not match VERSION (${version}).`
    };
  }

  return {
    ok: true,
    message: `package.json version matches VERSION (${version}).`
  };
}

function validatePackageConfig(root) {
  const packagePath = path.join(root, "package.json");

  if (!exists(packagePath)) {
    return [
      {
        ok: false,
        message: "package.json missing."
      }
    ];
  }

  const packageJson = JSON.parse(fs.readFileSync(packagePath, "utf8"));

  return [
    {
      ok: packageJson.name === "copilotops",
      message: `package.json name is ${packageJson.name || "missing"}; expected copilotops.`
    },
    {
      ok: Boolean(packageJson.bin && packageJson.bin.copilotops),
      message: "package.json bin.copilotops is required."
    },
    {
      ok: packageJson.private === true,
      message: "package.json private must be true for the private GitHub repo access model."
    }
  ];
}

async function validate(options) {
  const root = path.resolve(options.source);
  let failures = 0;
  let warnings = 0;

  console.log("# CopilotOps Framework Validation");
  console.log("");
  console.log(`Root: ${root}`);
  console.log("");

  console.log("## Required Files");
  for (const file of REQUIRED_FILES) {
    const p = path.join(root, file);

    if (exists(p)) {
      console.log(`- OK: ${file}`);
    } else {
      console.log(`- FAIL: ${file}`);
      failures++;
    }
  }

  console.log("");
  console.log("## Version Consistency");

  try {
    const versionCheck = validateVersionMatch(root);
    if (versionCheck.ok) {
      console.log(`- OK: ${versionCheck.message}`);
    } else {
      console.log(`- FAIL: ${versionCheck.message}`);
      failures++;
    }
  } catch (error) {
    console.log(`- FAIL: Could not validate version: ${error.message}`);
    failures++;
  }

  console.log("");
  console.log("## Package Configuration");

  try {
    for (const packageCheck of validatePackageConfig(root)) {
      if (packageCheck.ok) {
        console.log(`- OK: ${packageCheck.message}`);
      } else {
        console.log(`- FAIL: ${packageCheck.message}`);
        failures++;
      }
    }
  } catch (error) {
    console.log(`- FAIL: Could not validate package configuration: ${error.message}`);
    failures++;
  }

  console.log("");
  console.log("## Planning Prompt Safety");

  const promptsDir = path.join(root, "templates", ".github", "prompts");

  for (const prompt of PLANNING_PROMPTS) {
    const p = path.join(promptsDir, prompt);

    if (!exists(p)) {
      console.log(`- WARN: ${prompt} missing`);
      warnings++;
      continue;
    }

    const content = fs.readFileSync(p, "utf8");

    if (!content.includes("APPROVE PLAN")) {
      console.log(`- FAIL: ${prompt} missing APPROVE PLAN`);
      failures++;
    } else {
      console.log(`- OK: ${prompt} includes APPROVE PLAN`);
    }
  }

  console.log("");
  console.log("## Result");

  if (failures > 0) {
    console.log(`Status: RED (${failures} failures, ${warnings} warnings)`);
    process.exitCode = 1;
  } else if (warnings > 0) {
    console.log(`Status: YELLOW (${warnings} warnings)`);
  } else {
    console.log("Status: GREEN");
  }

  log.ok("Validation complete.");
}

module.exports = { validate };
