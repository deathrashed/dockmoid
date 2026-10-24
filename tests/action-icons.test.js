const fs = require('fs'), path = require('path'), vm = require('vm'), assert = require('node:assert/strict');
const context = {}; vm.createContext(context);
vm.runInContext(fs.readFileSync(path.join(__dirname, '../contents/lib/actionIcons.js'), 'utf8'), context);
const componentDir = path.join(__dirname, '../contents/ui/components');
for (const name of ['document-view','document-properties','text-x-generic','text-x-log','configure','preferences-desktop-icons','docker','insert-link','edit-copy','edit-delete','process-stop','media-playback-start','media-playback-stop','media-playback-pause','view-refresh','package-upgrade','media-playlist-repeat','window-pin','window-unpin','document-edit','edit-undo','window-maximize','window-restore','chevron-down']) {
  assert.equal(typeof context.path, 'function', 'action paths have one source of truth');
  const file = path.resolve(componentDir, context.path(name));
  assert.ok(fs.existsSync(file), `${name} resolves to an existing SVG: ${file}`);
  assert.match(fs.readFileSync(file, 'utf8'), /<svg/, `${name} is valid artwork`);
  if (name !== 'docker') assert.match(file, /assets\/lucide\//, `${name} uses the same action icon family`);
}
assert.notEqual(context.path('document-view'), context.path('document-properties'), 'details and raw inspect have distinct semantic icons');
assert.notEqual(context.path('configure'), context.path('preferences-desktop-icons'), 'manage and customize have distinct semantic icons');
console.log('all action glyphs resolve to bundled, consistent artwork');

const svgContext={}; vm.createContext(svgContext);
vm.runInContext(fs.readFileSync(path.join(__dirname,'../contents/lib/actionSvg.js'),'utf8').replace(/^\.pragma library\n/,''),svgContext);
for(const glyph of ['document-view','document-properties','configure','preferences-desktop-icons','docker','insert-link','edit-delete','view-refresh']) {
  const name=path.basename(context.path(glyph),'.svg');
  assert.ok(svgContext.artwork[name], `${glyph} has inline SVG artwork`);
  const colored=decodeURIComponent(svgContext.url(name,'#eff0f1').split(',').slice(1).join(','));
  assert.match(colored, /#eff0f1/, 'theme colour is injected without GPU masking');
  assert.doesNotMatch(colored, /currentColor/, 'SVG has an explicit renderer-independent colour');
}

// Only the icons the code names are embedded; each must match its bundled file.
for(const name of Object.keys(svgContext.artwork).filter(n=>!n.startsWith('logo-'))) {
  const original=fs.readFileSync(path.join(__dirname,'../contents/assets/lucide',name+'.svg'),'utf8').replace('stroke="#000000"','stroke="currentColor"');
  assert.equal(svgContext.artwork[name],original, `${name}.svg stays in sync with the generated colour-safe artwork`);
}

for (const layer of ['ring','whale']) {
  const name='logo-dockmoid-'+layer;
  assert.ok(svgContext.artwork[name], 'panel layers have software-renderer-safe artwork');
  const colored=decodeURIComponent(svgContext.url(name,'#ff8800'));
  assert.match(colored, /ff8800/);
  assert.doesNotMatch(colored, /currentColor|%23000000/);
}
