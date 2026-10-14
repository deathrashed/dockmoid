const fs=require('fs'),vm=require('vm'),assert=require('assert/strict'),path=require('path');
const c={};vm.createContext(c);
const file=path.join(__dirname,'../contents/lib/profiles.js');
assert.ok(fs.existsSync(file),'versioned profile/settings helper is available');vm.runInContext(fs.readFileSync(file,'utf8'),c);
const imported=JSON.stringify({version:1,profiles:[{id:'server',name:'Server',values:{engineCommand:'podman',activeContext:'server',probes:'web=https://example.com/',startCommand:'rm -rf dangerous',unknown:'ignored'}}]});
let data=c.parse(imported,false);
assert.equal(data.profiles[0].values.engineCommand,undefined,'imports exclude shell-bearing engine commands by default');
assert.equal(data.profiles[0].values.startCommand,undefined);
assert.equal(data.profiles[0].values.probes,'web=https://example.com/');
data=c.parse(imported,true);assert.equal(data.profiles[0].values.engineCommand,'podman');
assert.equal(data.profiles[0].values.unknown,undefined);
assert.throws(()=>c.parse('{"version":99,"profiles":[]}',false),/version/i);
const page={cfg_engineCommand:'docker',cfg_probes:'web=https://example.com/',cfg_updateCache:'private-cache',cfg_customIconFiles:'{}'};
const snap=c.capture(page);assert.equal(snap.engineCommand,'docker');assert.equal(snap.updateCache,undefined);
const view=c.parseViews('[{"name":"Problems","search":"web","mode":2,"problems":true},{"name":"Cards","mode":3},{"name":"bad","mode":99}]');assert.equal(view.length,2);assert.equal(view[0].mode,2);assert.equal(view[1].mode,3);assert.equal(view[0].detailLevel,1);
const minimal=c.parseViews('[ {"name":"Minimal","mode":0,"detailLevel":0} ]');assert.equal(minimal[0].detailLevel,0);

function savedProfiles(count) {
  return {version:1,profiles:Array.from({length:count},(_,i)=>({id:`saved-${i}`,name:`Saved ${i}`,values:{engineCommand:'docker'}}))};
}
const atLimit=c.upsert(savedProfiles(99),{id:'new-profile',name:'New',values:{engineCommand:'podman'}});
assert.equal(atLimit.profiles.length,100,'saving the 100th profile succeeds');
assert.throws(()=>c.upsert(savedProfiles(100),{id:'new-profile',name:'New',values:{}}),/100|limit/i,'new saves are rejected at the cap');
const updatedAtLimit=c.upsert(savedProfiles(100),{id:'saved-0',name:'Saved 0',values:{engineCommand:'podman'}});
assert.equal(updatedAtLimit.profiles.length,100,'updating an existing profile remains possible at the cap');
assert.equal(updatedAtLimit.profiles[0].values.engineCommand,'podman');

const mergedAtLimit=c.merge(savedProfiles(99),{version:1,profiles:[{id:'incoming',name:'Incoming',values:{probes:'web=https://example.com/'}}]},'import-');
assert.equal(mergedAtLimit.profiles.length,100,'importing the 100th profile succeeds');
const fullExisting=savedProfiles(100);
assert.throws(()=>c.merge(fullExisting,{version:1,profiles:[{id:'incoming',name:'Incoming',values:{}}]},'import-'),/100|limit/i,'merged imports above the cap are rejected');
assert.equal(fullExisting.profiles.length,100,'a rejected import does not mutate the existing profile list');

const export99=c.prepareExport(savedProfiles(99),{id:'current-1',name:'Current settings',values:{engineCommand:'podman',probes:'web=https://example.com/'}},false);
assert.equal(export99.includedCurrent,true);
assert.equal(c.parse(JSON.stringify(export99.data),false).profiles.length,100,'export with room remains valid');
assert.equal(export99.data.profiles[99].values.engineCommand,undefined,'default export omits commands from current settings');
const export100=c.prepareExport(savedProfiles(100),{id:'current-2',name:'Current settings',values:{engineCommand:'podman'}},true);
assert.equal(export100.includedCurrent,false,'export at the cap skips the extra current-settings profile');
assert.equal(c.parse(JSON.stringify(export100.data),true).profiles.length,100,'export of 100 saved profiles remains valid');
console.log('profiles: versioning, explicit command import, schema filtering, cache exclusion and saved views pass');

const presentation=c.parse(JSON.stringify({version:1,profiles:[{id:'appearance',name:'Appearance',values:{defaultGridDetailLevel:3,defaultTableDetailLevel:0,resourceBarMax:10,panelStyle:4}}]}),false).profiles[0].values;
assert.equal(presentation.defaultGridDetailLevel,3);
assert.equal(presentation.defaultTableDetailLevel,0);
assert.equal(presentation.resourceBarMax,10);
assert.equal(presentation.panelStyle,4);

const filtered=c.parseViews('[{"name":"Stopped","mode":3,"state":"stopped"},{"name":"Old","mode":0}]');
assert.equal(filtered[0].state,'stopped');assert.equal(filtered[1].state,'all');
