/* Structured deployment input. Imported commands are parsed, never evaluated. */
function quote(s) { return "'" + String(s).replace(/'/g,"'\\''") + "'"; }
function absolutePath(s,home) {
    s=String(s||"").trim();if(s==='~')s=home;else if(s.indexOf('~/')===0)s=home+s.slice(1);
    if(s.charAt(0)!=='/' || /[\x00-\x1f]/.test(s) || s.split('/').indexOf('..')>=0)throw Error('Use an absolute folder path without .. or control characters.');
    return s.replace(/\/+$/,'') || '/';
}
function validName(s) { return /^[a-z0-9][a-z0-9_-]{0,62}$/.test(String(s)); }
function imageReference(s,registry) {
    s=String(s||'').trim();if(!/^[A-Za-z0-9][A-Za-z0-9._:/@-]*$/.test(s))throw Error('Enter a valid image name or registry/name:tag.');
    registry=String(registry||'docker.io').replace(/\/+$/,'');
    if(!/^[A-Za-z0-9][A-Za-z0-9.:-]*$/.test(registry))throw Error('The default registry must be a hostname, optionally with a port.');
    var first=s.split('/')[0];
    if(registry!=='docker.io' && !(s.indexOf('/')>=0 && (/[.:]/.test(first)||first==='localhost')))s=registry+'/'+s;
    return s;
}
function words(text) {
    var out=[],word='',mode='',escape=false,started=false;
    text=String(text||'');
    for(var i=0;i<text.length;i++) {
        var c=text.charAt(i);
        if(escape){escape=false;if(c!=='\n'){word+=c;started=true;}continue;}
        if(c==='$' && text.charAt(i+1)==='(' && mode!=="'")throw Error('Host command substitutions cannot be imported. Enter their resolved value.');
        if(c==='\\' && mode!=="'"){if(mode==='\"' && ['$', '`', '\\', '\"', '\n'].indexOf(text.charAt(i+1))<0){word+=c;started=true;continue;}escape=true;continue;}
        if(mode){if(c===mode)mode='';else word+=c;started=true;continue;}
        if(c==='"'||c==="'"){mode=c;started=true;continue;}
        if(/\s/.test(c)){if(started){out.push(word);word='';started=false;}continue;}
        if(/[;&|<>`]/.test(c))throw Error('Import one docker run command, without host shell operators.');
        word+=c;started=true;
    }
    if(mode||escape)throw Error('Close all quotes and escapes in the command.');
    if(started)out.push(word);return out;
}
function importRun(text) {
    var a=words(text),i=0;
    if(a[i]==='docker'||a[i]==='podman')i++;
    if(a[i]==='container')i++;
    if(a[i++]!=='run')throw Error('Paste a docker run or podman run command.');
    var r={name:'',image:'',ports:[],mounts:[],environment:[],restart:'unless-stopped',network:'',command:[]};
    while(i<a.length && a[i].charAt(0)==='-') {
        var raw=a[i++],eq=raw.indexOf('='),key=eq>=0?raw.slice(0,eq):raw,value=eq>=0?raw.slice(eq+1):null;
        if(['-d','--detach'].indexOf(key)>=0)continue;
        if(key==='--'){break;}
        if(['-i','-t','-it','-ti','--interactive','--tty'].indexOf(key)>=0){r.stdinOpen=r.stdinOpen||/i|interactive/.test(key);r.tty=r.tty||/t|tty/.test(key);continue;}
        if(/^-[pev].+/.test(key)&&key.charAt(1)!=='-'){value=key.slice(2);key=key.slice(0,2);}
        if(['--name','-p','--publish','-v','--volume','-e','--env','--restart','--network','-w','--workdir','-u','--user'].indexOf(key)<0)throw Error('Unsupported import option: '+key+'. Use the form or a Compose file for this option.');
        if(value===null){if(i>=a.length)throw Error('Missing value for '+key);value=a[i++];}
        if(key==='--name')r.name=value;
        else if(key==='-p'||key==='--publish')r.ports.push(value);
        else if(key==='-v'||key==='--volume')r.mounts.push(value);
        else if(key==='-e'||key==='--env')r.environment.push(value);
        else if(key==='--restart')r.restart=value;
        else if(key==='--network')r.network=value;
        else if(key==='-w'||key==='--workdir')r.workdir=value;
        else if(key==='-u'||key==='--user')r.user=value;
    }
    if(i>=a.length)throw Error('The command is missing an image.');r.image=a[i++];r.command=a.slice(i);
    if(!r.name)r.name=r.image.split('/').pop().split(/[:@]/)[0].toLowerCase().replace(/[^a-z0-9_-]/g,'-');
    return r;
}
function lines(s) { return Array.isArray(s)?s:String(s||'').split(/\r?\n/).map(function(x){return x.trim();}).filter(Boolean); }
function literal(s) { return String(s).replace(/\$/g,function(){return '$$';}); }
function port(s) {
    if(!/^(?:(?:\d{1,3}\.){3}\d{1,3}:|\[[0-9a-fA-F:]+\]:)?\d{1,5}:\d{1,5}(?:\/(?:tcp|udp|sctp))?$/.test(s))throw Error('Ports must use host:container, for example 127.0.0.1:8080:80.');
    var nums=s.replace(/\/(tcp|udp|sctp)$/,'').split(':').slice(-2);
    if(nums.some(function(x){return Number(x)<1||Number(x)>65535;}))throw Error('Ports must be between 1 and 65535.');return s;
}
function recipe(input,settings,home) {
    var name=String(input.name||'').trim();if(!validName(name))throw Error('Use a lower-case project name with letters, digits, dashes or underscores.');
    var directory=absolutePath(settings.deploymentDirectory||home+'/docker',home)+'/'+name;
    var storage=absolutePath(settings.deploymentStorageDirectory||home+'/docker-data',home)+'/'+name;
    var image=imageReference(input.image,settings.deploymentRegistry);
    var service={image:literal(image),container_name:name};
    var restart=input.restart||settings.deploymentRestartPolicy||'unless-stopped';
    if(['no','always','unless-stopped','on-failure'].indexOf(restart)<0 && !/^on-failure:\d+$/.test(restart))throw Error('Choose a supported restart policy.');
    service.restart=restart;
    var ports=lines(input.ports);if(ports.length)service.ports=ports.map(port);
    var env={};lines(input.environment).forEach(function(s){var p=s.indexOf('=');if(p<0){if(!/^[A-Za-z_][A-Za-z0-9_]*$/.test(s))throw Error('Environment entries must use NAME or NAME=value.');env[s]=null;}else{if(p<1||!/^[A-Za-z_][A-Za-z0-9_]*$/.test(s.slice(0,p)))throw Error('Environment entries must use NAME or NAME=value.');env[s.slice(0,p)]=literal(s.slice(p+1));}});if(Object.keys(env).length)service.environment=env;
    var volumes={},folders=[];
    var mounts=lines(input.mounts);
    if(input.managedData){var target=String(input.dataTarget||'/data');if(target.charAt(0)!=='/'||/[\x00-\x1f:]/.test(target))throw Error('The data mount target must be an absolute container path.');mounts.push(storage+':'+target);folders.push(storage);}
    service.volumes=mounts.map(function(s){
        var parts=s.split(':');if(parts.length<2||parts.length>3)throw Error('Mounts must use source:/container/path[:ro].');
        var source=parts[0],target=parts[1],mode=parts[2]||'rw';
        if(target.charAt(0)!=='/'||/[\x00-\x1f]/.test(target)||['ro','rw'].indexOf(mode)<0)throw Error('Use an absolute container mount path and optional ro/rw mode.');
        var mount={target:literal(target),read_only:mode==='ro'};
        if(source.charAt(0)==='/'||source.indexOf('~/')===0){mount.type='bind';mount.source=literal(absolutePath(source,home));}
        else {if(!/^[A-Za-z0-9][A-Za-z0-9_.-]+$/.test(source))throw Error('Use an absolute host path or named volume.');volumes[source]={name:source};mount.type='volume';mount.source=source;}
        return mount;
    });if(!service.volumes.length)delete service.volumes;
    if(input.command && (Array.isArray(input.command)?input.command.length:String(input.command).trim()))service.command=(Array.isArray(input.command)?input.command:words(input.command)).map(literal);
    if(input.workdir)service.working_dir=literal(absolutePath(input.workdir,'/'));
    if(input.user)service.user=literal(input.user);
    if(input.stdinOpen)service.stdin_open=true;if(input.tty)service.tty=true;
    var network=String(input.network||settings.deploymentNetwork||'').trim();
    var doc={services:{}};doc.services[name]=service;
    if(['host','none','bridge'].indexOf(network)>=0)service.network_mode=network;
    else if(network){if(!/^[A-Za-z0-9][A-Za-z0-9_.-]*$/.test(network))throw Error('Use a network name.');service.networks=[network];doc.networks={};doc.networks[network]={external:true};}
    if(Object.keys(volumes).length)doc.volumes=volumes;
    return {name:name,image:image,directory:directory,storage:storage,folders:folders,file:directory+'/compose.json',document:doc,json:JSON.stringify(doc,null,2)+'\n'};
}
function searchResults(text) {
    return String(text||'').split(/\r?\n/).filter(Boolean).map(function(line){var r=JSON.parse(line);return {name:String(r.Name||r.name||''),description:String(r.Description||r.description||''),stars:String(r.StarCount||r.Stars||r.star_count||0),official:r.IsOfficial==='[OK]'||r.IsOfficial===true};}).filter(function(r){return r.name!=='';});
}
function matchesState(row,filter) {
    var state=String(row.containerState||row.state||'').toLowerCase();
    if(!filter||filter==='all')return true;
    if(filter==='not-created')return state==='not-created';
    if(filter==='stopped')return ['exited','created','dead'].indexOf(state)>=0;
    if(filter==='unhealthy')return state==='running' && row.health==='unhealthy';
    return state===filter;
}
function buildCommand(plan,compose,start) {
    var dir=quote(plan.directory), file=quote(plan.file), marker=quote(plan.directory+'/.dockmoid-project');
    var fail="printf '%s\\n' 'Existing project does not match the reviewed Dockmoid recipe; choose another name.' >&2; exit 1;";
    var cmd="umask 077; if test -e "+dir+"; then if test -L "+dir+" || test -L "+file+" || test -L "+marker+" || ! test -f "+marker+" || ! test -f "+file+"; then "+fail+" fi; else mkdir -p "+quote(plan.directory.slice(0,plan.directory.lastIndexOf('/')))+" && mkdir "+dir+" && printf '%s' "+quote(plan.json)+" > "+file+" && printf '%s\\n' 'Dockmoid project v1' > "+marker+" || exit 1; fi; ";
    cmd+="printf '%s' "+quote(plan.json)+" | cmp -s "+file+" - || { "+fail+" }; ";
    for(var i=0;i<plan.folders.length;i++)cmd+="mkdir -p "+quote(plan.folders[i])+" && ";
    var base=compose+" -p "+quote(plan.name)+" -f "+file;
    return cmd+base+" config --quiet && "+base+" pull && "+base+(start?" up -d":" create");
}
