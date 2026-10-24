// Recovery advice fits the connection: no Start or docker-group advice where it cannot apply.
const vm = require("node:vm"), fs = require("node:fs"), path = require("node:path"), assert = require("node:assert/strict"), test = require("node:test");
const R = {}; vm.createContext(R);
vm.runInContext(fs.readFileSync(path.join(__dirname, "../contents/lib/recovery.js"), "utf8").replace(/^\.pragma library\s*/, ""), R);
const plan = (ctx) => JSON.parse(JSON.stringify(R.plan(ctx)));

test("a local system Docker that is down can be started only when allowed", () => {
  assert.deepEqual(plan({problem: "down", canControlService: true}).actions, ["start", "retry", "settings"]);
  assert.deepEqual(plan({problem: "down", canControlService: false}).actions, ["retry", "settings"]);
});
test("a remote host never offers Start or local commands", () => {
  for (const problem of ["down", "permission"]) {
    const p = plan({problem, remote: true, canControlService: true});
    assert.ok(!p.actions.includes("start")); assert.equal(p.command, "");
  }
});
test("rootless and Podman get user-level commands, not the docker group", () => {
  assert.equal(plan({problem: "permission", rootless: true}).command, "systemctl --user start docker");
  assert.equal(plan({problem: "down", podman: true}).command, "systemctl --user start podman.socket");
  assert.equal(plan({problem: "permission"}).command, "sudo usermod -aG docker $USER");
});
test("a missing CLI points at installing it", () => {
  assert.equal(plan({problem: "missing", podman: true}).cause, "podman-missing");
  assert.deepEqual(plan({problem: "missing", remote: true}).actions, ["install", "settings"]);
});
