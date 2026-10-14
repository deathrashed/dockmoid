const vm = require("node:vm");
const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");

const context = {};
vm.createContext(context);
vm.runInContext(
  fs.readFileSync(path.join(__dirname, "../contents/lib/status.js"), "utf8").replace(/^\.pragma library\s*/, ""),
  context
);

const cases = [
  ["Up 4 hours", "running", "4h"],
  ["Up 12 seconds", "running", "12s"],
  ["Up Less than a second", "running", "<1s"],
  ["Up 2 minutes", "running", "2m"],
  ["Up 1 day", "running", "1d"],
  ["Up 3 weeks", "running", "3w"],
  ["Up About 1 minute", "running", "1m"],
  ["Up About an hour", "running", "1h"],
  ["Up a minute", "running", "1m"],
  ["Up an hour", "running", "1h"],
  ["Up 4 hours (Paused)", "paused", "4h"],
  ["Restarting (1) 5 seconds ago", "restarting", "5s"],
  ["Exited (137) 3 days ago", "exited", "3d"],
];

for (const [status, state, expected] of cases) {
  assert.equal(context.compactStatus(status, state), expected, status);
}

assert.equal(context.compactStatus("Created", "created"), "Created");
assert.equal(context.compactStatus("", "paused"), "paused");
assert.equal(context.compactStatus("", "running", "4 hours ago"), "4h", "runningFor is used when Docker status is absent");
const exited = "Exited (137) 3 days ago";
context.compactStatus(exited, "exited");
assert.equal(exited, "Exited (137) 3 days ago", "the original status, including exit code, remains available for the tooltip");

console.log("status labels ok");
