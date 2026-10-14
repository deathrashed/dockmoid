const fs=require('node:fs'), path=require('node:path'), vm=require('node:vm'), assert=require('node:assert/strict');
const base=path.join(__dirname,'../contents');
const P={};vm.createContext(P);vm.runInContext(fs.readFileSync(path.join(base,'lib/parsers.js'),'utf8'),P);
const I={};vm.createContext(I);vm.runInContext(fs.readFileSync(path.join(base,'lib/icons.js'),'utf8'),I);
const source=fs.readFileSync(path.join(base,'ui/Backend/DockerBackend.qml'),'utf8');
function backend(names, extra={}) {
 const c={cfg:{},beginOperation:()=>true,finishOperation(){},readOnly:false,isPodman:false,engineName:"Docker",Engines:globalThis.__engineHelpers,engineBinary:'docker',i18n:(s,...xs)=>s.replace(/%(\d+)/g,(_,n)=>String(xs[n-1])), ...extra};c.backend=c;if(!c.runner)c.runner={run:(...args)=>c.run(...args)};vm.createContext(c);
 if(names.includes("prune"))names=["cleanupCommand",...names];
 for(const name of names){const start=source.indexOf('    function '+name+'(');assert.notEqual(start,-1,'backend method '+name+' exists');const end=source.indexOf('\n    }',start);vm.runInContext(source.slice(start,end+6),c);}
 return c;
}
const Engines={};vm.createContext(Engines);vm.runInContext(fs.readFileSync(path.join(base,'lib/engines.js'),'utf8'),Engines);
globalThis.__engineHelpers=Engines;
let failed=0;
function test(name,fn){try{fn();console.log('ok - '+name)}catch(e){failed++;console.error('FAIL - '+name+': '+e.message)}}
test('Docker 23 status health remains visible',()=>assert.equal(P.normalizeContainer({ID:'abc',Names:'web',State:'running',Status:'Up 1 hour (unhealthy)'}).health,'unhealthy'));
test('structured Compose labels preserve override files',()=>assert.equal(P.normalizeContainer({ID:'abc',Names:'web',Labels:{'com.docker.compose.project.config_files':'/srv/base.yml,/srv/override.yml'}}).composeFiles,'/srv/base.yml,/srv/override.yml'));
test('unknown image usage is not advertised as unused',()=>assert.equal(P.parseImages('{"ID":"abc","Repository":"web","Tag":"latest"}')[0].containers,-1));
test('malformed command output is distinguishable from zero containers',()=>assert.equal(P.isValidRecords('not-json'),false));
test('empty container list is valid',()=>assert.equal(P.isValidRecords(''),true));
test('prune expands the selected engine before appending flags',()=>{let command;const c=backend(['newOutputRequest','consumeOutputRequest','expand','prune'],{generation:0,outputRequestCounter:0,outputRequestSequences:({}),cfg:{pruneCommand:'{engine} system prune -f'},engineBinary:'docker --context lab',run:(cmd)=>command=cmd,correlatedOutputReady(){}});c.prune({images:true});assert.equal(command,'docker --context lab image prune -f -a && docker --context lab builder prune -f')});
test('failed stop preserves known running engine state',()=>{const c=backend(['expand','firstLine','stopEngine'],{cfg:{stopServiceCommand:'false',stopSocketCommand:'true'},engineActive:true,canControlService:true,actionDone(){},onEngineDown(){this.engineActive=false},engineStateChanged(){},refresh(){},run:(cmd,tag,cb)=>cb(1,'','denied')});c.stopEngine();assert.equal(c.engineActive,true)});
test('event fallback obeys the configured heartbeat',()=>{let calls=0;const c=backend(['tick'],{runner:{},refreshing:false,engineKnown:true,engineActive:true,downTicks:0,cfg:{updateInterval:60},eventsUsable:false,lastFullMs:Date.now(),refresh:()=>calls++,checkForChanges(){}});c.tick();assert.equal(calls,0)});
test('service icon override survives container ID recreation',()=>{assert.equal(typeof I.customKey,'function');assert.equal(I.customKey({id:'old',name:'web-1',project:'site',service:'web'},'local'),I.customKey({id:'new',name:'web-2',project:'site',service:'web'},'local'))});
test('custom icons are isolated by endpoint',()=>assert.notEqual(I.customKey({name:'web'},'local'),I.customKey({name:'web'},'remote')));
test('custom icon URL accepts only local supported artwork',()=>{assert.equal(I.localIconPath('file:///tmp/my%20icon.svg'),'/tmp/my icon.svg');assert.equal(I.localIconPath('https://example.com/a.svg'),'');assert.equal(I.localIconPath('file:///tmp/script.sh'),'')});
test('single-service Compose update leaves dependencies untouched',()=>{let cmd;const rec={id:'abc',name:'web',project:'site',service:'web',composeFiles:'/srv/base.yml,/srv/override.yml',composeWorkDir:'/srv'};const c=backend(['newOutputRequest','consumeOutputRequest','expand','shellQuote','composeRun'],{Parsers:P,generation:0,outputRequestCounter:0,outputRequestSequences:({}),cfg:{composeCommand:'{engine} compose'},canUseCompose:true,actionDone(){},correlatedOutputReady(){},groupMembers:()=>[],groupKeyOf:()=>'',muteContainer(){},run:(s)=>cmd=s,refresh(){},invalidateImage(){},validateCompose:(r,cb)=>cb(true,'')});c.composeRun(rec,'update-service-running','web');assert.match(cmd,/up -d --no-deps --force-recreate web/);assert.match(cmd,/-f '\/srv\/override.yml'/)});
if(failed){console.error(failed+' regression failures');process.exitCode=1}

test('read-only mode blocks mutation commands at the backend boundary',()=>{let launched=0,code;const c=backend(['run'],{readOnly:true,generation:0,pendingActions:0,Qt:{callLater:fn=>fn()},runner:{isPoll:()=>false,run:()=>launched++}});c.run('docker stop abc','stopOneCommand',(v)=>code=v);assert.equal(launched,0);assert.equal(code,126)});
test('obsolete host response cannot update a new connection',()=>{let completed;let changed=false;const c=backend(['run'],{generation:1,pendingActions:0,runner:{isPoll:()=>true,run:(cmd,tag,done)=>completed=done}});c.run('docker ps','list',()=>changed=true);c.generation=2;completed(0,'[]','');assert.equal(changed,false)});
if(failed)process.exitCode=1;
test('stopped Compose service update recreates then stops the service',()=>{let call;const c=backend(['updateContainer'],{readOnly:false,canUseCompose:true,muteContainer(){},composeRun:(rec,verb)=>call=verb,pullImage(){throw Error('must use Compose recipe')}});c.updateContainer({id:'x',project:'site',service:'web',isRunning:false});assert.equal(call,'update-service-stopped')});
test('running Compose service update recreates and starts the service',()=>{let call;const c=backend(['updateContainer'],{readOnly:false,canUseCompose:true,muteContainer(){},composeRun:(rec,verb)=>call=verb,pullImage(){throw Error('must use Compose recipe')}});c.updateContainer({id:'x',project:'site',service:'web',isRunning:true});assert.equal(call,'update-service-running')});
test('queued batch cannot continue on a different host',()=>{let callback,launched=0;const later=[];const c=backend(['updateMany'],{generation:1,batchUpdating:false,Qt:{callLater:fn=>later.push(fn)},updateContainer:(rec,done)=>{launched++;callback=done}});c.canUseCompose=true;c.updateMany([{name:'one',project:'site',service:'one'},{name:'two',project:'site',service:'two'}]);callback(true,'done');c.generation++;later[0]();assert.equal(launched,1)});
test('log output carries request identity and discards an older poll response',()=>{
 let callbacks=[];const ready=[],records=[];const c=backend(['newOutputRequest','consumeOutputRequest','nextOutputSequence','expand','shellQuote','containerVars','logsTitle','fetchLogs'],{Parsers:P,generation:7,outputRequestCounter:0,outputRequestSequences:({}),cfg:{logsCommand:'docker logs {id} --tail {tail}'},run:(cmd,tag,done)=>callbacks.push(done),recordOutput:(...args)=>records.push(args),correlatedOutputReady:(...args)=>ready.push(args)});
 const rec={id:'abc123',name:'web'};const id=c.newOutputRequest('logs',rec.id);c.fetchLogs(rec,50,id,7);c.fetchLogs(rec,50,id,7);
 callbacks[0](0,'old tail','');callbacks[1](0,'new tail','');
 assert.equal(ready.length,1);assert.deepEqual(ready[0].slice(0,5),['logs','abc123',7,id,2]);assert.equal(ready[0][6],'new tail');
 assert.equal(records.length,1);assert.deepEqual(records[0].slice(0,5),['logs','abc123',7,id,2]);
 c.fetchLogs(rec,50,id,7);c.generation=8;callbacks[2](0,'old host tail','');
 assert.equal(ready.length,1,'a response from the old context generation is ignored');
});
test('inspect output is correlated by request and context generation',()=>{
 let callback,ready;const c=backend(['newOutputRequest','consumeOutputRequest','nextOutputSequence','expand','shellQuote','containerVars','prettyJson','firstLine','fetchInspect'],{Parsers:P,generation:3,outputRequestCounter:0,outputRequestSequences:({}),cfg:{inspectCommand:'docker inspect {id}'},run:(cmd,tag,done)=>callback=done,recordOutput(){},correlatedOutputReady:(...args)=>ready=args});
 const rec={id:'def456',name:'db'};const id=c.newOutputRequest('inspect',rec.id);c.fetchInspect(rec,id,3);callback(0,'{"Name":"db"}','');
 assert.deepEqual(ready.slice(0,5),['inspect','def456',3,id,1]);assert.match(ready[6],/"Name": "db"/);
});
test('pull output uses its request token instead of its display title',()=>{
 let callback;const ready=[];const c=backend(['newOutputRequest','consumeOutputRequest','expand','shellQuote','containerVars','pullImage'],{Parsers:P,generation:4,outputRequestCounter:0,cfg:{pullImageCommand:'docker pull {image}'},outputRequestSequences:({}),correlatedOutputReady:(...args)=>ready.push(args),run:(cmd,tag,done)=>callback=done,actionDone(){},invalidateImage(){},updateState:({}),saveUpdateCache(){},refresh(){}});
 const rec={id:'ghi789',name:'api',image:'example/api:latest'};const id=c.newOutputRequest('pull',rec.id);c.pullImage(rec,null,id);callback(0,'pulled','');
 assert.equal(ready.length,2);assert.deepEqual(ready[0].slice(0,5),['pull','ghi789',4,id,0]);assert.deepEqual(ready[1].slice(0,5),['pull','ghi789',4,id,0]);assert.equal(ready[1][6],'pulled');
});
test('Compose output carries a request token and generation',()=>{
 let callback,ready;const rec={id:'jkl012',name:'web',project:'site',composeFiles:'/srv/compose.yml',composeWorkDir:'/srv',image:'web:latest'};const c=backend(['newOutputRequest','consumeOutputRequest','composeRun','expand','shellQuote'],{Parsers:P,generation:5,outputRequestCounter:0,outputRequestSequences:({}),cfg:{composeCommand:'docker compose'},canUseCompose:true,readOnly:false,validateCompose:(r,done)=>done(true,''),shellQuote:x=>"'"+x+"'",muteContainer(){},actionDone(){},correlatedOutputReady:(...args)=>ready=args,run:(cmd,tag,done)=>callback=done,refresh(){},invalidateImage(){}});
 const id=c.newOutputRequest('compose',rec.id);c.composeRun(rec,'up',rec.project,null,id,5);callback(0,'created','');
 assert.equal(ready[0],'compose');assert.equal(ready[1],'jkl012');assert.equal(ready[2],5);assert.equal(ready[3],id);assert.equal(ready[6],'created');
});
test('prune output includes its generated request identity',()=>{
 let callback,ready;const c=backend(['newOutputRequest','consumeOutputRequest','expand','prune'],{generation:9,outputRequestCounter:0,outputRequestSequences:({}),cfg:{pruneCommand:'docker system prune -f'},isPodman:false,correlatedOutputReady:(...args)=>ready=args,run:(cmd,tag,done)=>callback=done,actionDone(){},diskUsageKnown:true,refresh(){}});
 c.prune({images:false,volumes:false});callback(0,'reclaimed','');
 assert.equal(ready[0],'prune');assert.equal(ready[1],'');assert.equal(ready[2],9);assert.match(ready[3],/^9:/);assert.equal(ready[6],'reclaimed');
});
if(failed)process.exitCode=1;
test('original image reference replaces dangling short image ID',()=>{const r={id:'abc',image:'99582f104d04'};const c=backend(['applyStructuredLabels'],{Parsers:P,records:[r],labelCache:{abc:{ImageId:'sha256:old',ImageRef:'lscr.io/linuxserver/beets:latest',Labels:{}}}});c.applyStructuredLabels();assert.equal(r.image,'lscr.io/linuxserver/beets:latest');assert.equal(r.imageId,'sha256:old')});
if(failed)process.exitCode=1;
test('unconfigured web probes are unknown rather than failures',()=>{const r=P.normalizeContainer({ID:'abc',Names:'web',State:'running'});assert.equal(r.probe,'');assert.equal(r.probeMs,0);assert.equal(r.updateAvailable,false)});
if(failed)process.exitCode=1;
test('stopped containers with stale unhealthy health are not active problems',()=>{const c=backend(['isProblem'],{Parsers:P});assert.equal(c.isProblem({containerState:'exited',isRunning:false,health:'unhealthy',status:'Exited (0)'}),false);assert.equal(c.isProblem({containerState:'running',isRunning:true,health:'unhealthy',status:'Up'}),true)});
test('Dashboard Icons theme variants select light artwork on dark panels',()=>{const entries=I.parseLibrary('sample.svg\nsample-light.svg\nsample-dark.svg');assert.equal(I.libraryFile(entries,'sample',1,true),'sample-light.svg');assert.equal(I.libraryFile(entries,'sample',1,false),'sample-dark.svg')});
test('stopped Compose update pulls and force-recreates without starting the service',()=>{let cmd;const rec={id:'abc',name:'web',project:'site',service:'web',isRunning:false,composeFiles:'/srv/compose.yml',composeWorkDir:'/srv'};const c=backend(['newOutputRequest','consumeOutputRequest','composeRun','expand','shellQuote'],{Parsers:P,generation:0,outputRequestCounter:0,outputRequestSequences:({}),cfg:{composeCommand:'{engine} compose'},canUseCompose:true,actionDone(){},correlatedOutputReady(){},muteContainer(){},run:(s)=>cmd=s,refresh(){},invalidateImage(){},validateCompose:(r,cb)=>cb(true,'')});c.composeRun(rec,'update-service-stopped','web');assert.match(cmd,/pull web && .*up --no-start --no-deps --force-recreate web/) });

test('Compose menu diagnostics stay bounded and preserve project override files',()=>{
 for(const [verb,ending] of [['restart',' restart'],['ps',' ps -a'],['logs',' logs --no-color --tail 300']]) {
  let command;
  const c=backend(['newOutputRequest','consumeOutputRequest','expand','shellQuote','composeRun'],{Parsers:P,generation:0,outputRequestCounter:0,outputRequestSequences:({}),cfg:{composeCommand:'{engine} compose',logTailLines:300},canUseCompose:true,actionDone(){},correlatedOutputReady(){},groupMembers:()=>[],groupKeyOf:()=>'',muteContainer(){},run:(s)=>command=s,refresh(){},invalidateImage(){},validateCompose:(r,cb)=>cb(true,'')});
  c.composeRun({id:'abc',project:'site',service:'web',composeFiles:'/srv/base.yml,/srv/override.yml'},verb,'Project');
  assert.ok(command.endsWith(ending),verb+' uses the intended operation');
  assert.match(command,/-f '\/srv\/base.yml' -f '\/srv\/override.yml'/);
  assert.doesNotMatch(command,/--follow/,'menu output must complete rather than follow forever');
 }
});
if(failed)process.exitCode=1;

test('folder action opens project directories safely and refuses remote paths',()=>{
 let url,commands=0;const messages=[];const c=backend(['shellQuote','openContainerFolder'],{Parsers:P,remoteEngine:false,Qt:{openUrlExternally:u=>url=u},actionDone:(...v)=>messages.push(v),run:()=>commands++});
 c.openContainerFolder({id:'abc123',name:'demo',composeWorkDir:'/srv/My App'});assert.equal(url,'file:///srv/My%20App');assert.equal(commands,0);
 c.openContainerFolder({id:'abc123',name:'demo',composeFiles:'/srv/My App/compose.yaml'});assert.equal(url,'file:///srv/My%20App');
 c.remoteEngine=true;url=undefined;c.openContainerFolder({id:'abc123',composeWorkDir:'/srv/project'});assert.equal(url,undefined);assert.equal(commands,0);assert.ok(messages.length);
});
test('folder action opens the parent directory of a file bind mount',()=>{
 let url;const commands=[];const c=backend(['shellQuote','openContainerFolder'],{Parsers:P,remoteEngine:false,Qt:{openUrlExternally:u=>url=u},actionDone(){},engineBinary:'docker',run:(cmd,tag,cb)=>{commands.push(cmd);if(tag==='inspect-folder')cb(0,JSON.stringify([{Type:'bind',Source:'/srv/app/config.yaml'}]),'');else cb(0,'/srv/app','')}});
 c.openContainerFolder({id:'abc123',name:'demo'});assert.equal(url,'file:///srv/app');assert.equal(commands.length,2);assert.match(commands[1],/test -d '\/srv\/app\/config.yaml'/);
});
if(failed)process.exitCode=1;
