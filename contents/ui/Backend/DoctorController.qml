import QtQuick
import "../../lib/parsers.js" as Parsers

Item {
    id: root
    required property var backend
    visible: false
    property bool scanning: false
    property bool executing: false
    property var checks: ({})
    property var images: ({})
    property var plans: []
    property string output: ""
    property string progress: ""
    property double checkedAt: 0
    Connections {
        target: root.backend
        function onGenerationChanged() {root.scanning=false;root.executing=false;root.checkedAt=0;root.plans=[];root.checks=({});root.images=({});root.progress=i18n("Connection changed · run Check again")}
    }
    readonly property var findings: {
        const revision = backend.revision
        let result = []
        if (!backend.engineActive) result.push({kind:"overview",title:i18n("Engine connection unavailable"),evidence:backend.lastError || i18n("The engine did not answer."),id:"",action:"",help:"https://docs.docker.com/engine/daemon/troubleshoot/"})
        backend.records.forEach(function(rec) {
            const checked = root.checks[rec.id] || {}, state = checked.state || {}
            const health = state.Health || {}, history = health.Log || []
            if (backend.isProblem(rec)) result.push({kind:"containers",title:rec.name + " · " + (rec.state === "restarting" ? i18n("Restarting") : rec.health === "unhealthy" ? i18n("Health check failed") : rec.state),evidence:rec.status + (state.Error ? "\n" + state.Error : "") + (history.length ? "\n" + String(history[history.length-1].Output || "").slice(0,1500) : ""),id:rec.id,action:rec.state === "paused" ? "" : "restart",help:"https://docs.docker.com/reference/dockerfile/#healthcheck"})
            if (rec.state === "not-created") result.push({kind:"compose",title:rec.name + " · " + i18n("Not created"),evidence:i18n("Configured service %1/%2 has no existing container. Nothing will start automatically.",rec.project,rec.service),id:rec.id,action:"start",help:"https://docs.docker.com/reference/cli/docker/compose/up/"})
            if (checked.restartCount > 0) result.push({kind:"containers",title:rec.name + " · " + i18n("%1 recorded restarts",String(checked.restartCount)),evidence:i18n("Docker reports a restart count of %1. This alone does not prove a restart loop. State: %2; exit code: %3",String(checked.restartCount),rec.state,String(state.ExitCode === undefined ? "Unavailable" : state.ExitCode)),id:rec.id,action:"",help:"https://docs.docker.com/engine/containers/start-containers-automatically/"})
            if (root.images[rec.image] && !root.images[rec.image].available) result.push({kind:"compose",title:rec.name + " · " + i18n("Image unavailable locally"),evidence:rec.image + "\n" + i18n("The selected engine could not inspect this image. It may need pulling or may require registry access."),id:rec.id,action:"pull",help:"https://docs.docker.com/reference/cli/docker/image/pull/"})
        })
        backend.configuredServices.forEach(function(service) {
            (service.missingBindPaths || []).forEach(function(path) {
                const rec = backend.records.find(function(r) { return r.project === service.project && r.service === service.service })
                result.push({kind:"compose",title:service.name + " · " + i18n("Bind path unavailable"),evidence:path + "\n" + i18n("This path was missing or inaccessible to your user during Compose discovery. Verify mounts and permissions before starting."),id:rec ? rec.id : "",action:"",help:"https://docs.docker.com/engine/storage/bind-mounts/"})
            })
        })
        if (backend.discoveryError) result.push({kind:"compose",title:i18n("Compose discovery needs attention"),evidence:backend.discoveryError,id:"",action:"",help:"https://docs.docker.com/reference/cli/docker/compose/config/"})
        if (backend.actionError || backend.lastError) result.push({kind:"overview",title:i18n("Recent reported error"),evidence:backend.actionError || backend.lastError,id:"",action:"",help:"https://docs.docker.com/engine/daemon/troubleshoot/"})
        return result
    }
    function scan(force) {
        if(force===false && checkedAt>0 && Date.now()-checkedAt<30000)return
        if (scanning || executing) return
        backend.refresh({force:true,withStats:true,withDisk:true})
        if (!backend.engineActive) { checkedAt=Date.now();return }
        scanning=true; checks=({}); images=({}); output=""; progress=i18n("Reading engine diagnostics…")
        const epoch=backend.generation, records=backend.records.slice(), queue=[]
        const seen={}
        records.forEach(function(rec) {
            if (rec.state !== "not-created" && /^[a-f0-9]+$/.test(rec.id)) queue.push({kind:"container",rec:rec})
            if (rec.image && !seen[rec.image]) {seen[rec.image]=true;queue.push({kind:"image",rec:rec})}
        })
        function next() {
            if (epoch !== backend.generation) {root.scanning=false;return}
            if (!queue.length) {root.scanning=false;root.checkedAt=Date.now();root.progress=i18n("Checks complete · no changes made");return}
            const job=queue.shift(), rec=job.rec
            root.progress=i18n("Checking %1",rec.name)
            const format='{\"state\":{{json .State}},\"restartCount\":{{json .RestartCount}},\"ports\":{{json .NetworkSettings.Ports}},\"mounts\":{{json .Mounts}},\"networks\":{{json .NetworkSettings.Networks}}}'
            const cmd=job.kind === "container" ? backend.engineBinary + " inspect --format " + backend.shellQuote(format) + " " + backend.shellQuote(rec.id)
                : backend.engineBinary + " image inspect --format '{{json .Config.Labels}}' " + backend.shellQuote(rec.image)
            backend.run(cmd,"diagnostic-doctor",function(code,out,err) {
                if (epoch !== backend.generation) {root.scanning=false;return}
                try {
                    if (job.kind === "container") {let result=Object.assign({},root.checks);result[rec.id]=code===0?JSON.parse(out):{error:backend.firstLine(err)};root.checks=result}
                    else {let result=Object.assign({},root.images);result[rec.image]={available:code===0,labels:code===0?JSON.parse(out)||{}:{}};root.images=result}
                } catch(e) {root.output+=i18n("Could not decode diagnostic output for %1",rec.name)+"\n"}
                Qt.callLater(next)
            },{timeout:20000})
        }
        next()
    }
    function validUrl(url) { return /^https?:\/\/[^\s/@]+(?::\d+)?(?:\/[^\s]*)?$/.test(String(url)) }
    function linksFor(rec) {
        if (!rec) return []
        const metadata=(images[rec.image] || {}).labels || {}, links=[]
        const fields=[['org.opencontainers.image.source',i18n("Source repository")],['org.opencontainers.image.url',i18n("Project")],['org.opencontainers.image.documentation',i18n("Documentation")],['org.opencontainers.image.releases',i18n("Release notes")],['org.opencontainers.image.issues',i18n("Issue tracker")]]
        const compose=backend.labelCache[Parsers.shortId(rec.id)] || {}, labels=compose.Labels || {}
        fields.forEach(function(field) {
            const value=metadata[field[0]] || labels[field[0]]
            if (value && root.validUrl(value)) links.push({label:field[1],url:String(value),origin:metadata[field[0]]?i18n("Image metadata · %1",field[0]):i18n("Compose/container label · %1",field[0])})
        })
        const configured=backend.configuredServices.find(function(s){return s.project===rec.project && s.service===rec.service})
        if (configured && configured.links) configured.links.forEach(function(link){if(root.validUrl(link.url))links.push({label:link.label,url:link.url,origin:i18n("Compose label · %1",link.key)})})
        try { const custom=JSON.parse(backend.cfg.userServiceLinks || "{}")[rec.image] || [];custom.forEach(function(link){if(root.validUrl(link.url)){for(let i=links.length-1;i>=0;i--)if(links[i].label===link.label)links.splice(i,1);links.push({label:link.label,url:link.url,origin:i18n("User supplied")})}}) } catch(e) {}
        let image=String(rec.image).replace(/@.*$/,""), pieces=image.split("/"), registry=""
        if (pieces.length===1) registry="https://hub.docker.com/_/"+pieces[0].split(":")[0]
        else if (pieces[0]==="docker.io" || (pieces[0].indexOf(".")<0 && pieces[0].indexOf(":")<0)) registry="https://hub.docker.com/r/"+image.replace(/^docker.io\//,"").replace(/:[^/]+$/,"")
        else if (pieces[0]==="ghcr.io") registry="https://github.com/"+pieces[1]+"/"+pieces.slice(2).join("/").split(":")[0]+"/pkgs/container/"+pieces.slice(2).join("/").split(":")[0]
        if (registry && validUrl(registry)) links.push({label:i18n("Image registry"),url:registry,origin:i18n("Derived from image reference; destination not verified")})
        return links
    }
    function saveLink(rec,label,url) {
        if (!rec || !label.trim() || !validUrl(url)) return false
        let all={};try {all=JSON.parse(backend.cfg.userServiceLinks || "{}")}catch(e){}
        let entries=all[rec.image] || [];entries=entries.filter(function(l){return l.label!==label.trim()});entries.push({label:label.trim(),url:url.trim()});all[rec.image]=entries;backend.cfg.userServiceLinks=JSON.stringify(all);return true
    }
    function plan(rec,action) {
        if (!rec || backend.readOnly) return null
        let command="", expected="", downtime=false
        if (action === "pull") {command=backend.engineBinary+" pull "+backend.shellQuote(rec.image);expected=i18n("Download the image only. Existing containers and their running state are unchanged.")}
        else if (action === "start" && rec.state !== "not-created") {command=backend.containerCommand(backend.cfg.startOneCommand,rec);expected=i18n("Start this existing container.")}
        else if (action === "restart" && rec.state !== "not-created") {command=backend.containerCommand(backend.cfg.restartOneCommand,rec);expected=i18n("Restart this container. Its service will be interrupted.");downtime=!!rec.isRunning}
        else if ((action === "start" || action === "recreate") && backend.canUseCompose && rec.project && rec.service && rec.composeFiles && Parsers.isSafeToken(rec.project) && Parsers.isSafeToken(rec.service)) {
            const base=backend.expand(backend.cfg.composeCommand,{})+" -p "+rec.project+" "+Parsers.composeFileArgs(rec.composeFiles,backend.shellQuote)
            const checks=String(rec.composeFiles).split(",").map(function(f){return "test -r "+backend.shellQuote(f.trim())}).join(" && ")
            command=checks+" && "+(rec.composeWorkDir?"cd "+backend.shellQuote(rec.composeWorkDir)+" && ":"")
                +(action==="recreate"?base+" pull "+rec.service+" && ":"")+base+" up "+(action==="recreate"&&!rec.isRunning?"--no-start":"-d")+" --no-deps "+(action==="recreate"?"--force-recreate ":"")+rec.service
            expected=action==="start"?i18n("Create and start only this Compose service. Dependencies are not started."):i18n("Pull and replace only this service, preserving its running/stopped state. Container writable-layer changes are lost; mounted data and volumes are retained.")
            downtime=action==="recreate"&&!!rec.isRunning
        }
        if (!command) return null
        const configured=backend.configuredServices.find(function(service){return service.project===rec.project&&service.service===rec.service})
        if (configured && configured.missingBindPaths && configured.missingBindPaths.length && action!=="pull")
            expected+="\n"+i18n("Warning: bind paths were missing or inaccessible during the last scan: %1. Starting with an unavailable mount can expose an empty directory instead of the intended data.",configured.missingBindPaths.join(", "))
        return {key:rec.id+":"+action,id:rec.id,name:rec.name,action:action,command:command,expected:expected,downtime:downtime,selected:true,generation:backend.generation,state:rec.state,image:rec.image}
    }
    function addPlan(rec,action) { const p=plan(rec,action);if(!p)return false;plans=plans.filter(function(x){return x.key!==p.key}).concat([p]);return true }
    function cleanupPlan(kind) {
        if (backend.readOnly || backend.isPodman) return
        const p={key:"cleanup:"+kind,id:"",name:kind==="images"?i18n("Dangling images"):i18n("Build cache"),action:"cleanup",command:backend.engineBinary+(kind==="images"?" image prune -f":" builder prune -f"),expected:i18n("Remove only the selected unused data. Containers, networks, bind mounts and volumes are retained."),downtime:false,selected:true,generation:backend.generation}
        plans=plans.filter(function(x){return x.key!==p.key}).concat([p])
    }
    function selectPlan(index,selected) {const list=plans.slice();list[index]=Object.assign({},list[index],{selected:selected});plans=list}
    function executeSelected() {
        if (executing || scanning || backend.readOnly) return
        const queue=plans.filter(function(p){return p.selected});if(!queue.length)return
        executing=true;output="";const epoch=backend.generation
        function next() {
            if (epoch!==backend.generation) {root.executing=false;root.progress=i18n("Stopped: engine connection changed");return}
            if (!queue.length) {root.executing=false;root.progress=i18n("Selected actions finished · review output");backend.refresh({force:true,withStats:true,withDisk:true});return}
            const p=queue.shift(), rec=p.id?backend.findRecord(p.id):null
            if (p.generation!==epoch || (p.id && (!rec || rec.state!==p.state || rec.image!==p.image))) {root.output+=p.name+": "+i18n("Skipped: state changed. Preview this action again.")+"\n";Qt.callLater(next);return}
            if (rec && !backend.beginOperation(rec,i18n("Doctor · working…"))) {root.output+=p.name+": "+i18n("Skipped: another action is running")+"\n";Qt.callLater(next);return}
            root.progress=i18n("Running %1",p.name);root.output+="$ "+p.command+"\n"
            backend.run(p.command,"doctor-action",function(code,out,err){
                root.output+=(out||"")+(err?"\n"+err:"")+"\n"+p.name+": "+(code===0?i18n("Completed"):i18n("Failed (exit %1)",String(code)))+"\n\n"
                if(rec)backend.finishOperation(rec,code===0,code===0?i18n("Doctor action completed"):backend.firstLine(err)||i18n("Failed"))
                Qt.callLater(next)
            },{timeout:900000})
        }
        next()
    }
}
