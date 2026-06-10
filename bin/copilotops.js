#!/usr/bin/env node

const { run } = require("../src/cli");

run(process.argv.slice(2)).catch((error) => {
  console.error("");
  console.error("CopilotOps failed:");
  console.error(error && error.message ? error.message : error);
  process.exit(1);
});
