// SharedSettings keeps several widgets on one configuration without letting a
// fresh widget overwrite a configured one or echo back what it just received.
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const assert = require("node:assert/strict");
const test = require("node:test");

const source = fs.readFileSync(path.join(__dirname, "../contents/ui/Backend/SharedSettings.qml"), "utf8");
function shared(extra) {
  const c = Object.assign({ localKeys: ["popupWidth", "serviceSectionSettings", "shareSettings", "sharedSettingsPushAt"],
    lastSnapshot: "", appliedAt: 0, started: true, instanceId: "1", path: "/tmp/s.json", folder: "/tmp",
    backend: { shellQuote: (s) => "'" + s + "'" }, console }, extra);
  c.root = c;
  for (const name of ["sharedKeys", "snapshot", "apply", "check", "push", "pull"]) {
    const start = source.indexOf("    function " + name + "(");
    const end = source.indexOf("\n    }", start);
    vm.runInNewContext(source.slice(start, end + 6).replace(/^    function (\w+)/, "root.$1 = function $1"), c);
  }
  return c;
}
function config(values) { return Object.assign({ keys() { return Object.keys(this).filter((k) => typeof this[k] !== "function"); } }, values); }

test("local keys are neither shared nor taken", () => {
  const cfg = config({ customIcons: "a", popupWidth: 300, shareSettings: true });
  const c = shared({ cfg });
  c.apply({ customIcons: "b", popupWidth: 900, unknownKey: 1 });
  assert.equal(cfg.customIcons, "b");
  assert.equal(cfg.popupWidth, 300);
  assert.equal(cfg.unknownKey, undefined);
  assert.deepEqual(JSON.parse(c.snapshot()), { customIcons: "b" });
});

test("taking settings does not write them back", () => {
  const writes = [];
  const cfg = config({ customIcons: "a", shareSettings: true });
  const c = shared({ cfg, runner: { run: (cmd) => writes.push(cmd) } });
  c.lastSnapshot = c.snapshot();
  c.apply({ customIcons: "b" });
  c.check();
  assert.equal(writes.length, 0);
  cfg.customIcons = "c";
  c.check();
  assert.equal(writes.length, 1);
  assert.match(writes[0], /"customIcons":"c"/);
});

test("own and older files are ignored", () => {
  let reply;
  const cfg = config({ customIcons: "a", shareSettings: true });
  const c = shared({ cfg, runner: { run: (cmd, tag, done) => (reply = done) } });
  c.pull(); reply(0, JSON.stringify({ version: 1, writer: "1", savedAt: 5, values: { customIcons: "mine" } }), "");
  assert.equal(cfg.customIcons, "a");
  c.appliedAt = 10;
  c.pull(); reply(0, JSON.stringify({ version: 1, writer: "2", savedAt: 9, values: { customIcons: "old" } }), "");
  assert.equal(cfg.customIcons, "a");
  c.pull(); reply(0, JSON.stringify({ version: 1, writer: "2", savedAt: 11, values: { customIcons: "new" } }), "");
  assert.equal(cfg.customIcons, "new");
});
