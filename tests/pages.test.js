// The page registry Go to lists and goToPage opens.
const vm = require("node:vm"), fs = require("node:fs"), path = require("node:path"), assert = require("node:assert/strict"), test = require("node:test");
const root = path.join(__dirname, "..");
const load = (file) => { const c = {}; vm.createContext(c); vm.runInContext(fs.readFileSync(path.join(root, "contents/lib", file), "utf8").replace(/^\.pragma library\s*/, ""), c); return c; };
const P = load("pages.js"), Icons = load("actionIcons.js");
const pages = JSON.parse(JSON.stringify(P.list()));

test("keys are unique; each has a label, a glyph and a known kind", () => {
  const keys = pages.map((p) => p.key);
  assert.equal(new Set(keys).size, keys.length);
  for (const p of pages) {
    assert.ok(p.key && p.label && p.glyph, p.key);
    assert.ok(["home", "stack", "inspector", "settings"].includes(p.kind), p.key);
  }
});
test("every glyph resolves to bundled artwork", () => {
  for (const p of pages) assert.ok(fs.existsSync(path.join(root, "contents/ui/components", Icons.path(p.glyph))), p.glyph);
});
test("find returns copies and null for unknown keys", () => {
  assert.equal(P.find("deploy").kind, "stack");
  assert.equal(P.find("nope"), null);
  P.find("deploy").kind = "home";
  assert.equal(P.find("deploy").kind, "stack");
});
test("SearchControl words every page with a literal i18n call", () => {
  const qml = fs.readFileSync(path.join(root, "contents/ui/components/SearchControl.qml"), "utf8");
  for (const p of pages) assert.match(qml, new RegExp(`\\b${p.key}: i18n\\("[^"]+"\\)`), p.key);
});
test("goToPage opens every stack page", () => {
  const qml = fs.readFileSync(path.join(root, "contents/ui/Views/PopupView.qml"), "utf8");
  const body = qml.slice(qml.indexOf("function goToPage("), qml.indexOf("function searchImages("));
  for (const p of pages.filter((p) => p.kind === "stack")) assert.match(body, new RegExp(`\\b${p.key}: function`), p.key);
});
