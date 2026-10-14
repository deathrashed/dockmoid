import QtQuick
import QtCore
import "../../lib/deployment.js" as Deploy

Item {
    id: root
    required property var backend
    readonly property var cfg: backend.cfg
    readonly property string home: decodeURIComponent(String(StandardPaths.writableLocation(StandardPaths.HomeLocation)).replace(/^file:\/\//,""))
    readonly property string projectRoot: { try { return Deploy.absolutePath(cfg.deploymentDirectory || home + "/docker",home) } catch(e) { return String(cfg.deploymentDirectory || "") } }
    readonly property bool canDeploy: backend.engineActive && backend.canUseCompose && !backend.readOnly && !backend.remoteEngine && !backend.isPodman
    property bool busy: false
    property string message: ""
    property string output: ""
    property bool failed: false
    property var results: []
    property bool searchPerformed: false
    property string lastFolder: ""

    function finish(code,out,err) {
        busy=false;failed=code!==0
        var streams=[]
        if(String(out||"").trim())streams.push(String(out).trim())
        if(String(err||"").trim())streams.push(String(err).trim())
        output=streams.join("\n")
        message=code===0?i18n("Command completed successfully."):i18n("Command failed with exit code %1.",code)
    }
    function search(query) {
        if(busy)return
        query=String(query).trim();if(!query)return
        if(query==="__popular__")query=""
        searchPerformed=true;busy=true;failed=false;message=i18n("Searching Docker Hub…");output="";results=[]
        const script=decodeURIComponent(String(Qt.resolvedUrl("../../scripts/search_images.py")).replace(/^file:\/\//,""))
        backend.run("python3 "+Deploy.quote(script)+" "+Deploy.quote(query),"diagnostic-registry-search",function(code,out,err){
            finish(code,"",err)
            if(code===0){try{results=JSON.parse(out);message=i18np("%1 image found","%1 images found",results.length)}catch(e){failed=true;message=String(e)}}
        },{timeout:30000})
    }

    function pull(image) {
        if(busy||backend.readOnly)return
        try{image=Deploy.imageReference(image,cfg.deploymentRegistry)}catch(e){message=String(e);failed=true;return}
        busy=true;failed=false;message=i18n("Pulling %1…",image);output=""
        backend.run(backend.engineBinary+" pull "+Deploy.quote(image),"deploy-pull",function(code,out,err){finish(code,out,err);backend.actionDone(i18n("Pull image"),code===0?i18n("Image pulled"):message,code===0);if(code===0)backend.refresh({force:true,withStats:false})})
    }
    function preview(input) { var plan=Deploy.recipe(input,cfg,home);plan.generation=backend.generation;plan.engine=backend.engineBinary;return plan }
    function create(plan,start) {
        if(busy)return
        if(!canDeploy || plan.generation!==backend.generation){failed=true;message=i18n("Connection or permissions changed. Review the project again.");return}
        // The caller passes the reviewed recipe. Never overwrite an existing project.
        var compose=backend.expand(cfg.composeCommand,{})
        var cmd=Deploy.buildCommand(plan,compose,start)
        busy=true;failed=false;message=i18n("Creating %1… Docker progress will appear when the command finishes.",plan.name);output="";lastFolder=plan.directory
        backend.run(cmd,"deploy-create",function(code,out,err){finish(code,out,err);if(code===0){message=i18n("%1 created. Project: %2",plan.name,plan.directory);backend.refresh({force:true,withStats:true})}else message=i18n("Creation failed with exit code %1. Project files: %2",code,plan.directory);backend.actionDone(plan.name,code===0?i18n("Project created"):message,code===0)})
    }
    function createResource(kind,name) {
        if(busy||backend.readOnly)return
        if(!/^[A-Za-z0-9][A-Za-z0-9_.-]*$/.test(name)){message=i18n("Use letters, digits, dots, dashes or underscores.");failed=true;return}
        if(kind!=="volume"&&kind!=="network")return
        busy=true;failed=false;message=i18n("Creating %1…",name);output=""
        backend.run(backend.engineBinary+" "+kind+" create "+Deploy.quote(name),"deploy-resource",function(code,out,err){finish(code,out,err);backend.actionDone(name,code===0?i18n("Created"):message,code===0);if(code===0)backend.fetchResources(kind+"s")})
    }
    Connections { target: root.backend; function onGenerationChanged(){root.busy=false;root.results=[];root.failed=true;root.message=i18n("Connection changed. Review your deployment for the selected host.")} }
}
