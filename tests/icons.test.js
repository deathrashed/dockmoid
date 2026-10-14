// node tests/icons.test.js — pure-JS helpers have no QML dependency.
const vm = require("vm"), fs = require("fs"), path = require("path"), assert = require("assert");
function load(file) {
  const ctx = {}; vm.createContext(ctx);
  vm.runInContext(fs.readFileSync(path.join(__dirname, "../contents/lib", file), "utf8"), ctx);
  return ctx;
}
const icons = load("icons.js");
const lib = icons.parseLibrary(["plex.svg","plex.png","pi-hole.svg","pi-hole-light.svg","pi-hole-dark.svg",
  "slskd.svg","portainer.svg","apache-couchdb.svg","only-light-light.svg","notes.txt"].join("\n"));
const m = (n, s, i, p) => icons.libraryMatch(lib, icons.libraryCandidates(n, s, i, p));
assert.strictEqual(m("pihole", "pihole", "pihole/pihole:latest", ""), "pi-hole");
assert.strictEqual(m("p", "", "portainer/portainer-ce:latest", ""), "portainer");
assert.strictEqual(m("slskdn", "", "ghcr.io/snapetech/slskdn:latest", ""), "slskd");
assert.strictEqual(m("x", "", "lscr.io/linuxserver/plex:latest", ""), "plex");
assert.strictEqual(m("caddy", "", "0c994536bddb", ""), null);
assert.strictEqual(m("obsidian", "", "couchdb:latest", ""), "apache-couchdb");
assert.strictEqual(lib.plex.file, "plex.svg");
assert.strictEqual(icons.libraryFile(lib, "pi-hole", 1, true), "pi-hole-light.svg");
assert.strictEqual(icons.libraryFile(lib, "pi-hole", 1, false), "pi-hole-dark.svg");
assert.strictEqual(icons.libraryFile(lib, "plex", 1, true), "plex.svg");
assert.strictEqual(icons.libraryFile(lib, "only-light", 0, true), "only-light-light.svg");
// user rules
const rules = icons.parseOverrides("myapp=plex\nsecret\n# c");
assert.strictEqual(icons.ruleMatch(rules, "x/myapp:1"), "plex");
assert.strictEqual(icons.ruleMatch(rules, "the-secret-box"), null);
assert.strictEqual(icons.ruleMatch(rules, "other"), undefined);
console.log("icons ok");
