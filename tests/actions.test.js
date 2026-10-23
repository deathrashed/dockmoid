// The shared container-action rules: one table of what each state allows,
// so a menu entry, a button and the handler behind them always agree.
const vm = require("node:vm");
const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");
const test = require("node:test");

const A = {};
vm.createContext(A);
vm.runInContext(fs.readFileSync(path.join(__dirname, "../contents/lib/actions.js"), "utf8").replace(/^\.pragma library\s*/, ""), A);

const rec = (state, extra) => Object.assign({ id: "abc123", name: "web", state, isRunning: state === "running" }, extra);
const on = (state, ctx) => {
  const can = A.allowed(rec(state), ctx || {});
  return Object.keys(can).filter((k) => can[k]).sort();
};

// What each state allows with full rights. "details" is always there.
const expected = {
  running: ["details", "exec", "forceRestart", "inspect", "kill", "logs", "pause", "remove", "rename", "restart", "stop", "update"],
  paused: ["details", "inspect", "kill", "logs", "remove", "rename", "resume", "stop", "update"],
  restarting: ["details", "forceRestart", "inspect", "kill", "logs", "remove", "rename", "restart", "stop", "update"],
  exited: ["details", "inspect", "logs", "remove", "rename", "restart", "start", "update"],
  created: ["details", "inspect", "logs", "remove", "rename", "start", "update"],
  dead: ["details", "inspect", "logs", "remove", "rename", "start", "update"],
  "not-created": ["create", "details"],
};

for (const [state, actions] of Object.entries(expected)) {
  test(`${state}: the allowed actions`, () => assert.deepEqual(on(state), actions));
}

test("a paused container never offers Restart, Pause or Start", () => {
  const can = A.allowed(rec("paused"), {});
  assert.equal(can.restart, false);
  assert.equal(can.pause, false);
  assert.equal(can.start, false);
  assert.equal(can.forceRestart, false);
});

test("read-only keeps looking but nothing that changes a container", () => {
  for (const state of Object.keys(expected)) {
    const allowed = on(state, { readOnly: true });
    const looks = expected[state].filter((a) => ["details", "logs", "inspect"].includes(a));
    assert.deepEqual(allowed, looks, state);
  }
});

test("a busy container keeps looking and Run Command, but no new action", () => {
  assert.deepEqual(on("running", { busy: true }), ["details", "exec", "inspect", "logs"]);
  assert.deepEqual(on("exited", { busy: true }), ["details", "inspect", "logs"]);
});

test("an unreachable engine allows no actions", () => {
  assert.deepEqual(on("running", { engineActive: false }), ["details", "inspect", "logs"]);
});

test("recreate needs a Compose service", () => {
  assert.equal(A.allowed(rec("running"), {}).recreate, false);
  assert.equal(A.allowed(rec("running"), { compose: true }).recreate, true);
  assert.equal(A.allowed(rec("not-created"), { compose: true }).recreate, false);
});

test("the primary button follows the state, not isRunning", () => {
  assert.deepEqual(JSON.parse(JSON.stringify(A.primary(rec("running"), {}))), { action: "stop", enabled: true });
  assert.deepEqual(JSON.parse(JSON.stringify(A.primary(rec("paused"), {}))), { action: "stop", enabled: true });
  assert.deepEqual(JSON.parse(JSON.stringify(A.primary(rec("restarting"), {}))), { action: "stop", enabled: true });
  assert.deepEqual(JSON.parse(JSON.stringify(A.primary(rec("exited"), {}))), { action: "start", enabled: true });
  assert.deepEqual(JSON.parse(JSON.stringify(A.primary(rec("not-created"), {}))), { action: "create", enabled: true });
  assert.deepEqual(JSON.parse(JSON.stringify(A.primary(rec("running"), { readOnly: true }))), { action: "stop", enabled: false });
});

test("model rows are read through containerState", () => {
  assert.equal(A.allowed({ id: "x", containerState: "paused", state: undefined }, {}).resume, true);
});

test("no record allows nothing", () => {
  const can = A.allowed(null, {});
  assert.deepEqual(Object.keys(can).filter((k) => can[k]), []);
});
