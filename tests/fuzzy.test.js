// Fuzzy navigation: letters in order, best words first.
const vm = require("node:vm"), fs = require("node:fs"), path = require("node:path"), assert = require("node:assert/strict"), test = require("node:test");
const F = {}; vm.createContext(F);
vm.runInContext(fs.readFileSync(path.join(__dirname, "../contents/lib/fuzzy.js"), "utf8").replace(/^\.pragma library\s*/, ""), F);

test("letters in order match, out of order do not", () => {
  assert.ok(F.score("dpl", "deploy") >= 0);
  assert.equal(F.score("ydp", "deploy"), -1);
  assert.equal(F.score("xyz", "deploy"), -1);
});
test("an empty query matches everything", () => assert.equal(F.score("", "anything"), 0));
test("separators and case are ignored", () => {
  assert.ok(F.score("pi hole", "pihole") >= 0);
  assert.ok(F.score("RES", "resources") >= 0);
});
test("word starts and runs rank above scattered letters", () => {
  assert.ok(F.score("dock", "dockmoid") > F.score("dock", "dmockodk"));
  assert.ok(F.score("sy", "syncthing") > F.score("sy", "homeassistant-sync"));
});
test("rank orders matches best first and drops the rest", () => {
  const names = ["resources", "deploy", "doctor", "health"];
  const out = JSON.parse(JSON.stringify(F.rank("de", names, (n) => n)));
  assert.equal(out[0], "deploy");
  assert.ok(!out.includes("health"));
});
