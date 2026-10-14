// Every glyph name the QML uses must resolve to a bundled lucide icon.
// A typo would otherwise show as an alert icon at runtime.
const vm = require("node:vm");
const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");
const test = require("node:test");

const root = path.join(__dirname, "..");
const context = {};
vm.createContext(context);
vm.runInContext(fs.readFileSync(path.join(root, "contents/lib/actionIcons.js"), "utf8").replace(/^\.pragma library\s*/, ""), context);

function qmlFiles(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    return entry.isDirectory() ? qmlFiles(full) : entry.name.endsWith(".qml") ? [full] : [];
  });
}

test("glyph names used in QML resolve to bundled artwork", () => {
  const bad = [];
  for (const file of qmlFiles(path.join(root, "contents/ui"))) {
    const text = fs.readFileSync(file, "utf8");
    const names = new Set();
    for (const match of text.matchAll(/glyph: ?"([a-z0-9-]+)"/g)) names.add(match[1]);
    for (const match of text.matchAll(/ActionIcons\.path\("([a-z0-9-]+)"\)/g)) names.add(match[1]);
    for (const match of text.matchAll(/glyph: ?[^"\n]*\? ?"([a-z0-9-]+)" ?: ?"([a-z0-9-]+)"/g)) { names.add(match[1]); names.add(match[2]); }
    for (const name of names) {
      if (name === "docker") continue;
      const target = context.path(name);
      if (!fs.existsSync(path.join(root, "contents/ui/components", target))) bad.push(`${path.relative(root, file)}: ${name}`);
    }
  }
  assert.deepEqual(bad, []);
});
