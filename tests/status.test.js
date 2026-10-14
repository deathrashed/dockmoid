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

// ---- presentation helpers ----
{
  assert.equal(context.statusTone("failed", "", true, false), "bad");
  assert.equal(context.statusTone("unhealthy", "", true, true), "bad");
  assert.equal(context.statusTone("paused", "", true, true), "warn");
  assert.equal(context.statusTone("restarting", "", true, true), "warn");
  assert.equal(context.statusTone("running", "", true, true), "text");
  assert.equal(context.statusTone("stopped", "", true, false), "muted");
  assert.equal(context.statusTone("running", "Done", true, true), "ok");
  assert.equal(context.statusTone("running", "Failed", false, true), "bad");
  assert.equal(context.glyphTone("failed", false), "bad");
  assert.equal(context.glyphTone("paused", true), "warn");
  assert.equal(context.glyphTone("running", true), "ok");
  assert.equal(context.glyphTone("stopped", false), "slate");
  assert.equal(context.glyphTone("not-created", false), "sky");
  assert.equal(context.statusGlyph("running", false, true, "always"), "circle-play");
  assert.equal(context.statusGlyph("stopped", false, false, "always"), "circle-pause");
  assert.equal(context.statusGlyph("not-created", false, false, "always"), "package-plus");
  assert.equal(context.isProblem("unhealthy"), true);
  assert.equal(context.isProblem("running"), false);
  assert.equal(context.statusGlyph("running", true, true, "always"), "view-refresh");
  assert.equal(context.statusGlyph("failed", false, false, "always"), "circle-x");
  assert.equal(context.statusGlyph("running", false, true, "attention"), "");
  assert.equal(context.statusGlyph("unhealthy", false, true, "attention"), "dialog-warning");
  assert.equal(context.statusGlyph("failed", false, false, "none"), "");
  assert.equal(context.prefixKey("restarting"), "restarting");
  assert.equal(context.prefixKey("running"), "");
  assert.equal(context.accentTone("running"), "ok");
  assert.equal(context.accentTone("failed"), "bad");
  assert.equal(context.accentTone("paused"), "warn");
  assert.equal(context.accentTone("stopped"), "");
  assert.equal(context.accentTone("not-created"), "");
  console.log("status presentation helpers ok");
}

{
  const spec = (attention) => JSON.parse(JSON.stringify(context.badgeSpec(attention)));
  assert.deepEqual(spec("running"), { key: "running", tone: "ok", variant: "ghost", glyph: "", dot: true });
  assert.equal(spec("failed").tone, "bad");
  assert.equal(spec("paused").tone, "amber");
  assert.equal(spec("not-created").variant, "outline");
  assert.equal(spec("stopped").key, "stopped");
  assert.equal(spec("anything-else").key, "stopped");
  console.log("status badge specs ok");
}
