const path = require("path");

function getRepoRootFromSource(source) {
  return path.resolve(source);
}

function getTemplatesGithubPath(source) {
  return path.join(getRepoRootFromSource(source), "templates", ".github");
}

function getTargetGithubPath(target) {
  return path.join(path.resolve(target), ".github");
}

module.exports = {
  getRepoRootFromSource,
  getTemplatesGithubPath,
  getTargetGithubPath
};
