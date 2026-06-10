const fs = require("fs");
const path = require("path");
const { init } = require("./commands/init");
const { link } = require("./commands/link");
const { health } = require("./commands/health");
const { validate } = require("./commands/validate");
const { rollback } = require("./commands/rollback");
const { doctor } = require("./commands/doctor");

function getVersion() {
  try {
    const packagePath = path.join(__dirname, "..", "package.json");
    const packageJson = JSON.parse(fs.readFileSync(packagePath, "utf8"));
    return packageJson.version || "1.0.0";
  } catch (_error) {
    return "1.0.0";
  }
}

function printHelp() {
  console.log(`
CopilotOps Framework v${getVersion()}

Usage:
  copilotops <command> [options]

Commands:
  init       Copy CopilotOps templates into the current project
  link       Link current project .github Copilot assets to central templates
  health     Check current project CopilotOps setup
  validate   Validate this CopilotOps framework repo
  doctor     Run full framework + target environment diagnostics
  rollback   Restore backed up CopilotOps-linked files/folders

Options:
  --target <path>       Target project path. Defaults to current directory.
  --source <path>       CopilotOps repo path. Defaults to current repo.
  --dry-run             Show what would happen without changing files.
  --force               Replace existing backups/links only when safe.
  --help                Show help.

Examples:
  copilotops health
  copilotops validate
  copilotops init --target C:\\SharedProjects\\CS_Datafactory_v2 --dry-run
  copilotops link --target C:\\SharedProjects\\CS_Datafactory_v2
  copilotops doctor --target C:\\SharedProjects\\CS_Datafactory_v2 --source C:\\SharedProjects\\CopilotOps
`);
}

function parseArgs(args) {
  const result = {
    command: args[0],
    options: {
      target: process.cwd(),
      source: path.join(__dirname, ".."),
      dryRun: false,
      force: false
    }
  };

  for (let i = 1; i < args.length; i++) {
    const arg = args[i];

    if (arg === "--target") {
      result.options.target = args[++i];
    } else if (arg === "--source") {
      result.options.source = args[++i];
    } else if (arg === "--dry-run") {
      result.options.dryRun = true;
    } else if (arg === "--force") {
      result.options.force = true;
    } else if (arg === "--help" || arg === "-h") {
      result.command = "help";
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }

  return result;
}

async function run(args) {
  if (args.length === 0 || args[0] === "--help" || args[0] === "-h") {
    printHelp();
    return;
  }

  const { command, options } = parseArgs(args);

  switch (command) {
    case "init":
      return init(options);
    case "link":
      return link(options);
    case "health":
      return health(options);
    case "validate":
      return validate(options);
    case "doctor":
      return doctor(options);
    case "rollback":
      return rollback(options);
    case "help":
      return printHelp();
    default:
      printHelp();
      throw new Error(`Unknown command: ${command}`);
  }
}

module.exports = { run };
