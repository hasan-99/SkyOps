function info(message) {
  console.log(`INFO  ${message}`);
}

function ok(message) {
  console.log(`OK    ${message}`);
}

function warn(message) {
  console.warn(`WARN  ${message}`);
}

function fail(message) {
  console.error(`FAIL  ${message}`);
}

module.exports = {
  info,
  ok,
  warn,
  fail
};
