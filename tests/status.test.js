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
  assert.equal(context.glyphTone("stopped", false), "rose");
  assert.equal(context.glyphTone("not-created", false), "blue");
  assert.equal(context.statusGlyph("running", false, true, "always"), "circle-play");
  assert.equal(context.statusGlyph("stopped", false, false, "always"), "circle-stop");
  assert.equal(context.statusGlyph("not-created", false, false, "always"), "circle-plus");
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

// Timeline: started/stopped/created ages for the line under a container's name.
{
  const now = Date.UTC(2026, 9, 24, 12), h = 3600000, d = 24 * h;
  const tl = (rec) => JSON.parse(JSON.stringify(context.timeline(rec, now)));
  assert.deepEqual(tl({state: "running", startedAtMs: now - 7 * h - 24 * 60000, createdMs: now - 7 * h - 25 * 60000}), [{kind: "up", at: now - 7 * h - 24 * 60000, span: "7h 24m"}]);
  // Restarted since a recent recreate: the uptime, then the container's age.
  assert.deepEqual(tl({state: "running", startedAtMs: now - 2 * h, createdMs: now - 23 * h}).map(e => e.kind + " " + e.span), ["up 2h", "created 23h"]);
  assert.deepEqual(tl({state: "exited", startedAtMs: now - 12 * d, finishedAtMs: now - 9 * d, createdMs: now - 20 * d}).map(e => e.kind + " " + e.span), ["down 9d"]);
  assert.deepEqual(tl({state: "created", createdMs: now - 2 * d}).map(e => e.kind + " " + e.span), ["created 2d"]);
  assert.deepEqual(tl({state: "not-created", createdMs: now - 2 * d}), []);
  assert.deepEqual(tl({state: "exited", status: "Exited (0) 2 days ago"}), []);
  assert.equal(context.span(45 * 1000), "45s"); assert.equal(context.span(3 * d + 5 * h), "3d 5h"); assert.equal(context.span(400 * d), "13mo");
}

// Diagnose: exit codes and the log lines worth reading first
assert.equal(context.exitMeaning(137, false), "killed");
assert.equal(context.exitMeaning(137, true), "oom");
assert.equal(context.exitMeaning(0, false), "clean");
assert.equal(context.exitMeaning(1, false), "app");
assert.equal(context.exitMeaning(-1, false), "");
assert.deepEqual(Array.from(context.problemLines("ok\nERROR: db refused\ninfo\nwarning: slow\n", 5)), ["ERROR: db refused", "warning: slow"]);

// Log digest: loops, recurring messages and single errors, with counts
{
  const lines = [];
  for (let i = 0; i < 6; i++) lines.push("2026-10-24T10:00:0" + i + "Z ERROR dial tcp 10.0.0." + i + ":5432 refused");
  lines.push("INFO started");
  for (let i = 0; i < 7; i++) lines.push("WARN cache miss key " + i * 3);
  lines.push("ERROR disk full");
  const d = context.digestLogs(lines.join("\n"));
  assert.equal(d.errors, 7); assert.equal(d.warnings, 7); assert.equal(d.lines, 15);
  assert.deepEqual(JSON.parse(JSON.stringify(d.items.map((i) => [i.kind, i.level, i.count]))), [["loop", "error", 6], ["loop", "warning", 7], ["single", "error", 1]]);
  assert.equal(d.items[0].sample, "ERROR dial tcp 10.0.0.0:5432 refused");
  assert.equal(context.digestLogs("").items.length, 0);
  // Same message spread across the tail (not back to back) is recurring, not a loop.
  const spread = [];
  for (let i = 0; i < 6; i++) { spread.push("ERROR upstream timeout"); spread.push("INFO tick " + i); }
  assert.equal(context.digestLogs(spread.join("\n")).items[0].kind, "recurring");
}

// Health: one key, tone and streak for Inspector · Health and Diagnose
{
  const hs = (facts, record, read) => JSON.parse(JSON.stringify(context.healthState(facts, record, read)));
  const running = {id: "abc", state: "running", health: ""};
  const facts = (health, check) => ({healthCheck: check === undefined ? "curl -f localhost" : check, health: health});
  assert.deepEqual(hs(facts({status: "healthy", failingStreak: 0}), running, true), {key: "healthy", tone: "ok", streak: 0, status: "healthy"});
  assert.deepEqual(hs(facts({status: "starting", failingStreak: 0}), running, true), {key: "starting", tone: "warn", streak: 0, status: "starting"});
  assert.deepEqual(hs(facts({status: "unhealthy", failingStreak: 3}), running, true), {key: "unhealthy", tone: "bad", streak: 3, status: "unhealthy"});
  assert.equal(hs(facts({status: "unhealthy", failingStreak: 0}), running, true).streak, 0);
  assert.equal(hs(facts({status: "weird", failingStreak: 0}), running, true).key, "other");
  // No healthcheck configured, or configured without a result yet.
  assert.deepEqual(hs(facts(null, ""), running, true), {key: "no-check", tone: "muted", streak: 0, status: ""});
  assert.equal(hs(facts(null), running, true).key, "no-result");
  // Not deployed, no container, inspect pending or answered with nothing.
  assert.equal(hs(null, {id: "x", state: "not-created"}, false).key, "not-created");
  assert.equal(hs(null, null, false).key, "none");
  assert.equal(hs(null, running, false).key, "reading");
  assert.deepEqual(hs(null, running, true), {key: "unknown", tone: "muted", streak: 0, status: ""});
  assert.equal(hs(null, Object.assign({}, running, {health: "none"}), true).key, "unknown");
  // Until inspect answers, the list's health word stands in.
  assert.deepEqual(hs(null, Object.assign({}, running, {health: "unhealthy"}), false), {key: "other", tone: "bad", streak: 0, status: "unhealthy"});
  console.log("health state ok");
}
