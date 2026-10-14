const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),cp=require('node:child_process');
const xml=fs.readFileSync(path.join(__dirname,'../contents/config/main.xml'),'utf8');
test('group actions propagate inventory failure rather than report false success',()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'dockmoid-group-'));
 try {
  const engine=path.join(dir,'engine');fs.writeFileSync(engine,'#!/bin/sh\nif [ "$1" = ps ]; then exit 7; fi\nprintf mutated > "'+dir+'/mutated"\n');fs.chmodSync(engine,0o700);
  for(const key of ['groupStartCommand','groupStopCommand','groupRestartCommand']) {
   const template=xml.match(new RegExp('<entry name="'+key+'"[\\s\\S]*?<default>([\\s\\S]*?)</default>'))[1].replace(/&amp;/g,'&').replace(/&lt;/g,'<').replace(/&gt;/g,'>');
   const cmd=template.replaceAll('{engine}',"'"+engine+"'").replaceAll('{project}','site');
   const result=cp.spawnSync('/bin/sh',['-c',cmd]);assert.equal(result.status,7,key+' must preserve failed inventory status');assert.equal(fs.existsSync(path.join(dir,'mutated')),false);
  }
 }finally{fs.rmSync(dir,{recursive:true,force:true})}
});
