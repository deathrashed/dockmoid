const vm = require("node:vm");
const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");
const test = require("node:test");

const root = path.join(__dirname, "..");
const context = {};
vm.createContext(context);
vm.runInContext(
  fs.readFileSync(path.join(root, "contents/lib/style.js"), "utf8").replace(/^\.pragma library\s*/, ""),
  context
);
const alpha = vm.runInContext("ALPHA", context);
// Arrays made inside the vm context have another Array prototype; copy them.
const surfaces = Array.from(vm.runInContext("SURFACES", context));

test("every token is a usable opacity", () => {
  for (const [name, value] of Object.entries(alpha)) {
    assert.ok(context.isValid(value), name);
  }
  assert.ok(!context.isValid(0));
  assert.ok(!context.isValid(1.2));
  assert.ok(!context.isValid("0.1"));
});

test("text opacities get softer from strong to soft", () => {
  const text = vm.runInContext("TEXT", context);
  assert.ok(text.strong > text.normal && text.normal > text.soft);
  for (const value of Object.values(text)) assert.ok(context.isValid(value));
});

test("wash and band opacities are usable and ordered", () => {
  const wash = vm.runInContext("WASH", context), border = vm.runInContext("WASH_BORDER", context), band = vm.runInContext("BAND", context);
  assert.ok(wash.rest < wash.hover && wash.hover < wash.selected);
  assert.ok(border.rest < border.hover && border.hover < border.selected);
  assert.ok(band.start > band.end);
  for (const value of [...Object.values(wash), ...Object.values(border), ...Object.values(band)]) assert.ok(context.isValid(value));
});

test("accent hues are distinct hex colours", () => {
  const hue = vm.runInContext("HUE", context);
  const values = Object.values(hue);
  assert.ok(values.length >= 7);
  for (const value of values) assert.match(value, /^#[0-9a-f]{6}$/);
  assert.equal(new Set(values).size, values.length);
});

test("fills get stronger from surface to hover", () => {
  const values = surfaces.map((name) => alpha[name]);
  assert.deepEqual(values, [...values].sort((a, b) => a - b));
  assert.equal(new Set(values).size, values.length);
});

test("lines get stronger from faint to strong", () => {
  const order = ["divider", "borderFaint", "border", "borderSoft", "borderAccent", "borderStrong"];
  const values = order.map((name) => alpha[name]);
  assert.deepEqual(values, [...values].sort((a, b) => a - b));
});

test("accent washes get stronger from weak to hover", () => {
  assert.ok(alpha.tintWeak < alpha.tintStrong);
  assert.ok(alpha.tintStrong < alpha.tintHover);
});

test("popup chrome uses tokens, not literal opacities", () => {
  // Compact (panel icon), BadgeOverlay and SectionTabButton compute colours
  // from other colours and are restyled separately.
  const skip = new Set(["Compact.qml", "BadgeOverlay.qml", "SectionTabButton.qml"]);
  const offenders = [];
  const walk = (dir) => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) { if (entry.name !== "config") walk(full); continue; }
      if (!entry.name.endsWith(".qml") || skip.has(entry.name)) continue;
      fs.readFileSync(full, "utf8").split("\n").forEach((line, index) => {
        for (const call of line.match(/Qt\.alpha\([^)]*\)/g) || []) {
          if (/(^|[^\w.])0?\.\d+\b/.test(call.slice(call.lastIndexOf(",") + 1))) offenders.push(`${path.relative(root, full)}:${index + 1}`);
        }
      });
    }
  };
  walk(path.join(root, "contents/ui"));
  assert.deepEqual(offenders, []);
});
