// The engine's display name must come from i18n, not refer back to itself:
// a self-referencing binding reads as an empty string everywhere it is shown.
const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");
const test = require("node:test");

test("engineName is defined from translated words", () => {
  const source = fs.readFileSync(path.join(__dirname, "../contents/ui/Backend/DockerBackend.qml"), "utf8");
  const line = source.split("\n").find((l) => /readonly property string engineName:/.test(l));
  assert.ok(line, "engineName property exists");
  assert.match(line, /i18n\("Podman"\)/);
  assert.match(line, /i18n\("Docker"\)/);
  assert.doesNotMatch(line.split(":").slice(2).join(":"), /(^|[^\w"])engineName/);
});
