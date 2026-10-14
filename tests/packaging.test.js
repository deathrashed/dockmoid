const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '..');
function fixture(t) {
    const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'dockmoid-package-'));
    t.after(() => fs.rmSync(temp, {recursive:true, force:true}));
    const data = path.join(temp, 'data with spaces');
    const installed = path.join(data, 'plasma/plasmoids/dockmoid.plasmoid');
    const bin = path.join(temp, 'bin');
    fs.mkdirSync(bin);
    fs.writeFileSync(path.join(bin, 'kpackagetool6'), `#!/bin/sh
target="$XDG_DATA_HOME/plasma/plasmoids/dockmoid.plasmoid"
while [ "$#" -gt 0 ]; do
 case "$1" in -r) rm -rf "$target"; exit 0;; --packageroot) target="$2/dockmoid.plasmoid"; shift 2;; -u|-i) source="$2"; shift 2;; *) shift;; esac
done
mkdir -p "$target"
cp -R "$source/." "$target/"
printf changed > "$target/partial"
printf called > "$XDG_DATA_HOME/package-tool-called"
[ "\${FAIL_PACKAGE:-0}" = 0 ]
`);
    fs.chmodSync(path.join(bin, 'kpackagetool6'), 0o755);
    return {temp, data, installed, env:{...process.env, XDG_DATA_HOME:data, PATH:bin+':'+process.env.PATH}};
}
function oldPackage(f) {
    fs.mkdirSync(f.installed, {recursive:true});
    fs.writeFileSync(path.join(f.installed,'old'), 'preserve me');
}
test('failed update restores the complete old package after partial tool writes', t => {
    const f=fixture(t); oldPackage(f);
    const result=spawnSync('sh',[path.join(root,'install.sh')],{env:{...f.env,FAIL_PACKAGE:'1'}});
    assert.notEqual(result.status,0);
    assert.ok(fs.existsSync(path.join(f.data,'package-tool-called')));
    assert.deepEqual(fs.readdirSync(f.installed),['old']);
    assert.equal(fs.readFileSync(path.join(f.installed,'old'),'utf8'),'preserve me');
});
test('failed first install removes only its partial package', t => {
    const f=fixture(t);
    const result=spawnSync('sh',[path.join(root,'install.sh')],{env:{...f.env,FAIL_PACKAGE:'1'}});
    assert.notEqual(result.status,0);
    assert.ok(fs.existsSync(path.join(f.data,'package-tool-called')));
    assert.equal(fs.existsSync(f.installed),false);
});
test('installer stages its own installed source before an update', t => {
    const f=fixture(t); fs.mkdirSync(f.installed,{recursive:true});
    for (const name of ['install.sh','contents','metadata.json']) fs.cpSync(path.join(root,name),path.join(f.installed,name),{recursive:true});
    const result=spawnSync('sh',[path.join(f.installed,'install.sh')],{env:f.env,encoding:'utf8'});
    assert.equal(result.status,0,result.stderr);
    assert.ok(fs.existsSync(path.join(f.installed,'contents/ui/main.qml')));
    assert.ok(fs.existsSync(path.join(f.data,'icons/hicolor/512x512/apps/dockmoid.png')));
});
test('release archive includes runtime files and notices, excludes scratch and secrets', t => {
    const f=fixture(t); const source=path.join(f.temp,'source'); fs.mkdirSync(source);
    for (const name of ['contents','metadata.json','install.sh','packaging','LICENSE','THIRD_PARTY_NOTICES.md','po','translate']) fs.cpSync(path.join(root,name),path.join(source,name),{recursive:true});
    fs.writeFileSync(path.join(source,'contents','.env'),'secret');
    for (const dir of ['work','scratch','.git','tmp']) {
        fs.mkdirSync(path.join(source,'contents',dir));
        fs.writeFileSync(path.join(source,'contents',dir,'private.md'),'secret');
    }
    const localeFile=path.join(source,'locale/en/LC_MESSAGES/dockmoid.mo');
    fs.mkdirSync(path.dirname(localeFile),{recursive:true}); fs.writeFileSync(localeFile,'locale fixture');
    const output=path.join(f.temp,'release.plasmoid');
    const result=spawnSync('python3',[path.join(source,'packaging/release.py'),output],{encoding:'utf8'});
    assert.equal(result.status,0,result.stderr);
    const listing=spawnSync('python3',['-c','import zipfile,sys; print("\\n".join(zipfile.ZipFile(sys.argv[1]).namelist()))',output],{encoding:'utf8'}).stdout.split('\n');
    for(const name of ['metadata.json','contents/ui/main.qml','contents/icons/dockmoid.png','contents/assets/library/NOTICE.md','LICENSE','packaging/dockmoid.plasmoid.appdata.xml','locale/en/LC_MESSAGES/dockmoid.mo']) assert.ok(listing.includes(name),name);
    assert.equal(listing.some(name=>name.includes('.env')||['/work/','/scratch/','/.git/','/tmp/'].some(part=>name.includes(part))),false);
});

test('lint propagates unexpected tool failures instead of filtering their output', t => {
    const f=fixture(t); const shim=path.join(f.temp,'broken-lint');
    fs.writeFileSync(shim,'#!/bin/sh\n[ "$1" = --version ] && exit 0\necho "fatal tool failure" >&2\nexit 23\n');
    fs.chmodSync(shim,0o755);
    const result=spawnSync('sh',[path.join(root,'tests/lint.sh')],{env:{...f.env,QMLLINT:shim},encoding:'utf8'});
    assert.equal(result.status,23,result.stderr);
    assert.match(result.stderr,/fatal tool failure/);
});
test('incomplete sources never invoke the package tool or change an installed package', t => {
    const f=fixture(t); oldPackage(f); const source=path.join(f.temp,'incomplete'); fs.mkdirSync(source);
    fs.copyFileSync(path.join(root,'install.sh'),path.join(source,'install.sh'));
    const result=spawnSync('sh',[path.join(source,'install.sh')],{env:f.env});
    assert.notEqual(result.status,0);
    assert.equal(fs.existsSync(path.join(f.data,'package-tool-called')),false);
    assert.deepEqual(fs.readdirSync(f.installed),['old']);
});
