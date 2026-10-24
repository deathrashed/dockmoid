const fs=require('fs'),vm=require('vm'),assert=require('node:assert/strict'),path=require('path'),os=require('os'),cp=require('child_process');
const d={};vm.createContext(d);vm.runInContext(fs.readFileSync(path.join(__dirname,'../contents/lib/deployment.js'),'utf8'),d);
const tmp=fs.mkdtempSync(path.join(os.tmpdir(),'dockmoid-deployment-'));
try {
 const cfg={deploymentDirectory:tmp+"/projects with 'quotes' $cash",deploymentStorageDirectory:tmp+'/storage',deploymentRegistry:'docker.io'};
 const imported=d.importRun("docker run -d --name demo -p 127.0.0.1:8080:80 -v demo-data:/data -e 'MESSAGE=a b $HOME' --restart unless-stopped nginx:alpine sh -c 'echo hello; echo world'");
 assert.equal(d.recipe({name:'inherit',image:'nginx',environment:'TZ'},cfg,tmp).document.services.inherit.environment.TZ,null);
 assert.equal(imported.image,'nginx:alpine');assert.equal(imported.name,'demo');assert.equal(imported.command[2],'echo hello; echo world');
 const plan=d.recipe({...imported,managedData:true,dataTarget:'/config'},cfg,tmp);
 assert.equal(plan.document.services.demo.environment.MESSAGE,'a b $$HOME');
 assert.equal(plan.document.volumes['demo-data'].name,'demo-data');
 assert.equal(plan.document.services.demo.volumes[1].source,tmp+'/storage/demo');
 assert.throws(()=>d.importRun('docker run nginx; touch /tmp/no'),/operators/);
 assert.throws(()=>d.importRun('docker run -e FOO=$(id) nginx'),/substitutions/);
 assert.throws(()=>d.importRun('docker run --privileged nginx'),/Unsupported/);
 assert.equal(d.importRun('docker run \\\n -d nginx').image,'nginx');
 assert.throws(()=>d.recipe({name:'../oops',image:'nginx'},cfg,tmp),/project name/);
 assert.throws(()=>d.recipe({name:'demo',image:'--help'},cfg,tmp),/image name/);
 assert.throws(()=>d.recipe({name:'demo',image:'nginx',ports:'99999:80'},cfg,tmp),/65535/);
 assert.throws(()=>d.recipe({name:'demo',image:'nginx',environment:'NOT KEY=value'},cfg,tmp),/NAME=value/);
 assert.equal(d.imageReference('group/app:latest','registry.example:5000'),'registry.example:5000/group/app:latest');
 assert.equal(d.imageReference('ghcr.io/user/app:1','registry.example'),'ghcr.io/user/app:1');
 assert.equal(d.recipe({name:'hosted',image:'nginx',network:'host'},cfg,tmp).document.services.hosted.network_mode,'host');
 const fake=tmp+'/fake compose';fs.writeFileSync(fake,'#!/bin/sh\nprintf "%s\\n" "$*" >> "$DOCKMOID_TEST_CALLS"\n', {mode:0o700});
 const log=tmp+'/calls';const env={...process.env,DOCKMOID_TEST_CALLS:log};
 let result=cp.spawnSync('/bin/sh',['-c',d.buildCommand(plan,d.quote(fake),false)],{env,encoding:'utf8'});
 assert.equal(result.status,0,result.stderr);
 assert.deepEqual(JSON.parse(fs.readFileSync(plan.file,'utf8')),JSON.parse(plan.json));
 assert.equal(fs.statSync(plan.file).mode&0o777,0o600);
 assert.ok(fs.existsSync(tmp+'/storage/demo'));
 let calls=fs.readFileSync(log,'utf8');assert.match(calls,/config --quiet/);assert.match(calls,/ pull/);assert.match(calls,/ create\n/);assert.doesNotMatch(calls,/ up -d/);
 result=cp.spawnSync('/bin/sh',['-c',d.buildCommand(plan,d.quote(fake),true)],{env,encoding:'utf8'});assert.equal(result.status,0,result.stderr);assert.match(fs.readFileSync(log,'utf8'),/ up -d/);
 // A retry can reuse only unchanged Dockmoid-owned files; never overwrite edits.
 fs.writeFileSync(plan.file,'user edits');result=cp.spawnSync('/bin/sh',['-c',d.buildCommand(plan,d.quote(fake),true)],{env,encoding:'utf8'});assert.notEqual(result.status,0);assert.equal(fs.readFileSync(plan.file,'utf8'),'user edits');
 const existing=d.recipe({name:'existing',image:'nginx'},cfg,tmp);fs.mkdirSync(existing.directory);fs.writeFileSync(existing.directory+'/keep','keep');result=cp.spawnSync('/bin/sh',['-c',d.buildCommand(existing,d.quote(fake),true)],{env,encoding:'utf8'});assert.notEqual(result.status,0);assert.equal(fs.readFileSync(existing.directory+'/keep','utf8'),'keep');
 assert.equal(d.matchesState({containerState:'paused'},'stopped'),false);assert.equal(d.matchesState({containerState:'exited'},'stopped'),true);assert.equal(d.matchesState({containerState:'running',health:'unhealthy'},'unhealthy'),true);assert.equal(d.matchesState({containerState:'exited',health:'unhealthy'},'unhealthy'),false);

 const linked=d.recipe({name:'linked',image:'nginx'},cfg,tmp);fs.mkdirSync(linked.directory);fs.writeFileSync(linked.file,linked.json);fs.symlinkSync(existing.directory+'/keep',linked.directory+'/.dockmoid-project');
 result=cp.spawnSync('/bin/sh',['-c',d.buildCommand(linked,d.quote(fake),true)],{env,encoding:'utf8'});assert.notEqual(result.status,0,'marker symlinks never establish project ownership');
 const source=fs.readFileSync(path.join(__dirname,'../contents/ui/backend/DeploymentController.qml'),'utf8');
 const start=source.indexOf('    function create(plan,start)');const end=source.indexOf('    function createResource',start);
 let dispatched=0;
 const controller={Deploy:d,canDeploy:true,busy:false,cfg:{composeCommand:'docker compose'},backend:{generation:2,expand:s=>s,run:()=>dispatched++},i18n:s=>s};vm.createContext(controller);vm.runInContext(source.slice(start,end),controller);
 controller.create({...plan,generation:1},true);assert.equal(dispatched,0,'host changes invalidate reviewed plans');
 controller.canDeploy=false;controller.create({...plan,generation:2},true);assert.equal(dispatched,0,'read-only/unavailable engines cannot deploy');
 controller.canDeploy=true;controller.create({...plan,generation:2},true);assert.equal(dispatched,1,'a reviewed current-host plan reaches the runner');
 console.log('deployment: safe command import, quoting, Compose recipes, stopped/start paths, retries, no-overwrite and state filters pass');
} finally {fs.rmSync(tmp,{recursive:true,force:true});}
