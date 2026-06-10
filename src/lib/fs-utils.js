const fs = require("fs");
const path = require("path");

function exists(p) {
  return fs.existsSync(p);
}

function ensureDir(dir, dryRun = false) {
  if (exists(dir)) {
    return;
  }

  if (dryRun) {
    return;
  }

  fs.mkdirSync(dir, { recursive: true });
}

function copyRecursive(source, target, dryRun = false) {
  const stat = fs.statSync(source);

  if (stat.isDirectory()) {
    ensureDir(target, dryRun);

    for (const item of fs.readdirSync(source)) {
      copyRecursive(path.join(source, item), path.join(target, item), dryRun);
    }

    return;
  }

  ensureDir(path.dirname(target), dryRun);

  if (!dryRun) {
    fs.copyFileSync(source, target);
  }
}

function removeRecursive(target, dryRun = false) {
  if (!exists(target)) {
    return;
  }

  if (!dryRun) {
    fs.rmSync(target, { recursive: true, force: true });
  }
}

function backupPath(target) {
  return `${target}.backup`;
}

function backupExisting(target, dryRun = false) {
  if (!exists(target)) {
    return false;
  }

  const backup = backupPath(target);

  if (exists(backup)) {
    throw new Error(`Backup already exists: ${backup}`);
  }

  if (!dryRun) {
    fs.renameSync(target, backup);
  }

  return true;
}

function isSymlinkOrJunction(target) {
  if (!exists(target)) {
    return false;
  }

  const stat = fs.lstatSync(target);
  return stat.isSymbolicLink();
}

function linkDirectory(source, target, dryRun = false) {
  ensureDir(path.dirname(target), dryRun);

  if (dryRun) {
    return;
  }

  const type = process.platform === "win32" ? "junction" : "dir";
  fs.symlinkSync(source, target, type);
}

function linkFile(source, target, dryRun = false) {
  ensureDir(path.dirname(target), dryRun);

  if (dryRun) {
    return;
  }

  try {
    fs.symlinkSync(source, target, "file");
  } catch (error) {
    if (process.platform !== "win32") {
      throw error;
    }

    fs.linkSync(source, target);
  }
}

module.exports = {
  exists,
  ensureDir,
  copyRecursive,
  removeRecursive,
  backupPath,
  backupExisting,
  isSymlinkOrJunction,
  linkDirectory,
  linkFile
};
