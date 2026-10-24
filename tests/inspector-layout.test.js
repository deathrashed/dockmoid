// Inspector layout: which page, shown or folded, below or beside the list.
const vm = require("node:vm"), fs = require("node:fs"), path = require("node:path"), assert = require("node:assert/strict"), test = require("node:test");
const L = {}; vm.createContext(L);
vm.runInContext(fs.readFileSync(path.join(__dirname, "../contents/lib/inspectorLayout.js"), "utf8").replace(/^\.pragma library\s*/, ""), L);
// Objects from the vm context have another Object prototype; compare plain copies.
const plain = (v) => JSON.parse(JSON.stringify(v));
const g = 18, header = Math.trunc(g * 2.4);
const env = (width, height) => ({width, height: height || 700, gridUnit: g, headerHeight: header});

test("defaults: Overview, shown, below the list", () => {
  assert.deepEqual(plain(L.normalize(undefined)), {page: "preview", shown: true, side: false});
  assert.deepEqual(plain(L.normalize({})), {page: "preview", shown: true, side: false});
});
test("legacy and unknown page names show Overview", () => {
  assert.equal(L.normalize({page: "stats"}).page, "preview");
  assert.equal(L.normalize({page: 3}).page, "preview");
  assert.equal(L.normalize({page: "logs"}).page, "logs");
  assert.equal(L.layout({page: "files"}, env(800)).page, "preview");
});
test("only a literal true counts for expanded and side", () => {
  assert.equal(L.normalize({expanded: "true"}).shown, false);
  assert.equal(L.normalize({side: 1}).side, false);
});
test("the open tab hides the pane; another tab opens its page", () => {
  let dock = {page: "preview", expanded: true, width: 500};
  dock = L.pressTab(dock, "preview");
  assert.deepEqual(plain(dock), {page: "preview", expanded: false, width: 500});
  dock = L.pressTab(dock, "preview");
  assert.equal(dock.expanded, true);
  dock = L.pressTab(dock, "logs");
  assert.deepEqual(plain(dock), {page: "logs", expanded: true, width: 500});
  dock = L.pressTab(L.toggleShown(dock), "events");
  assert.deepEqual([dock.page, dock.expanded], ["events", true]);
});
test("transitions leave the stored object alone", () => {
  const dock = {page: "logs", expanded: true};
  L.pressTab(dock, "logs"); L.toggleShown(dock); L.toggleSide(dock, true);
  assert.deepEqual(dock, {page: "logs", expanded: true});
});
test("toggleSide flips what is seen; without room it reads as below", () => {
  assert.equal(L.toggleSide({}, true).side, true);
  assert.equal(L.toggleSide({side: true}, true).side, false);
  assert.equal(L.toggleSide({side: true}, false).side, true);
});
test("side by side only when asked, shown and wide enough", () => {
  const wide = env(g * 40), narrow = env(g * 40 - 1);
  let out = L.layout({side: true}, wide);
  assert.deepEqual([out.roomForSide, out.sidePreferred, out.sideBySide, out.orientation], [true, true, true, "horizontal"]);
  out = L.layout({side: true}, narrow);
  assert.deepEqual([out.roomForSide, out.sidePreferred, out.sideBySide, out.orientation], [false, false, false, "vertical"]);
  out = L.layout({side: false}, wide);
  assert.equal(out.sideBySide, false);
});
test("a hidden inspector folds to the strip below the list", () => {
  const out = L.layout({side: true, expanded: false}, env(g * 50));
  assert.equal(out.sidePreferred, true);
  assert.equal(out.sideBySide, false);
  assert.equal(out.orientation, "vertical");
  assert.deepEqual(plain(out.pane), {minW: 0, prefW: -1, minH: header, maxH: header, prefH: header});
  assert.equal(out.listMinW, 0);
});
test("stacked sizes: per-page height, Overview default, at least 4 units", () => {
  assert.deepEqual(plain(L.layout({}, env(600, 700)).pane), {minW: 0, prefW: -1, minH: header, maxH: 16777215, prefH: g * 12});
  assert.equal(L.layout({page: "logs"}, env(600, 700)).pane.prefH, 700 * 0.55);
  assert.equal(L.layout({page: "logs", height_logs: 300, height_preview: 100}, env(600)).pane.prefH, 300);
  assert.equal(L.layout({height_preview: 10}, env(600)).pane.prefH, g * 4);
  assert.deepEqual([L.layout({}, env(600)).listMinW, L.layout({}, env(600)).listMinH], [0, g * 6]);
});
test("side by side sizes: minimum widths and the kept width", () => {
  let out = L.layout({side: true}, env(g * 45));
  assert.deepEqual(plain(out.pane), {minW: g * 24, prefW: g * 30, minH: 0, maxH: 16777215, prefH: g * 12});
  assert.equal(out.listMinW, g * 14);
  assert.equal(L.layout({side: true, width: 900}, env(g * 45)).pane.prefW, 900);
  assert.equal(L.layout({side: true, width: 100}, env(g * 45)).pane.prefW, g * 24);
});
test("a drag keeps the width side by side, else this page's height", () => {
  const side = {side: true, page: "logs"};
  assert.deepEqual(plain(L.resized(side, L.layout(side, env(g * 45)), 512.6, 400.2)), {side: true, page: "logs", width: 513});
  const below = {page: "compose"};
  assert.deepEqual(plain(L.resized(below, L.layout(below, env(600)), 600, 333.4)), {page: "compose", height_compose: 333});
  // Narrow with side asked for: stacked, so the height is kept.
  assert.equal(L.resized(side, L.layout(side, env(400)), 400, 250).height_logs, 250);
  const hidden = {expanded: false};
  assert.equal(L.resized(hidden, L.layout(hidden, env(600)), 600, 40), hidden);
});
