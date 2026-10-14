import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/deployment.js" as Deploy
import "../components" as Components
import "../../lib/style.js" as Style

Item {
    id: root
    required property var backend
    /* True when shown inside the main page's dock. */
    property bool embedded: false
    property int initialTab: 0
    signal closeRequested()
    readonly property var controller: backend.deployment
    readonly property var restartPolicies: [{label:i18n("Manual start"),value:"no"},{label:i18n("On failure"),value:"on-failure"},{label:i18n("Unless stopped"),value:"unless-stopped"},{label:i18n("Always"),value:"always"}]
    property var reviewed: null
    property var importedOptions: ({})
    property string formError: ""
    property bool searchExpanded: true
    property int searchOrder: 0
    property bool officialOnly: false
    readonly property var sortedResults: controller.results.filter(function(r){return !root.officialOnly || r.official}).slice().sort(function(a,b){return root.searchOrder===0 ? Number(b.stars)-Number(a.stars) : root.searchOrder===1 ? Number(b.pulls||0)-Number(a.pulls||0) : String(a.name).localeCompare(String(b.name))})
    property int outputPanelHeight: 112
    property bool outputPanelExpanded: false
    Connections { target: root.controller; function onBusyChanged() { if (root.controller.busy) root.outputPanelExpanded = true } }
    objectName: "deploymentPage"

    function show(tab) { if (tab !== undefined) tabs.currentIndex = tab; root.visible = true }
    function close() { root.closeRequested() }
    onInitialTabChanged: if (tabs) tabs.currentIndex = root.initialTab
    function input() {
        return Object.assign({}, importedOptions, {name:projectName.text,image:imageName.text,ports:ports.text,mounts:mounts.text,environment:environment.text,command:command.text,network:network.text,restart:restart.currentValue,managedData:managedData.checked,dataTarget:dataTarget.text})
    }
    function review() {
        try { root.reviewed=controller.preview(input());root.formError="";reviewDialog.open() }
        catch(e){root.formError=String(e)}
    }
    function useImage(name) {
        imageName.text=name
        if(!projectName.text)projectName.text=name.split('/').pop().split(/[:@]/)[0].toLowerCase().replace(/[^a-z0-9_-]/g,'-')
        tabs.currentIndex=1
    }
    function importCommand() {
        try {
            const r=Deploy.importRun(importText.text)
            importedOptions={workdir:r.workdir||"",user:r.user||"",stdinOpen:r.stdinOpen===true,tty:r.tty===true}
            projectName.text=r.name;imageName.text=r.image;ports.text=r.ports.join('\n');mounts.text=r.mounts.join('\n');environment.text=r.environment.join('\n');network.text=r.network
            command.text=r.command.map(Deploy.quote).join(' ')
            const idx=root.restartPolicies.findIndex(function(x){return x.value===r.restart});if(idx>=0)restart.currentIndex=idx
            else throw Error(i18n("Choose the restart policy manually: %1",r.restart))
            managedData.checked=false;formError="";tabs.currentIndex=1
        }catch(e){formError=String(e)}
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Components.PageHeader {
            compact: root.embedded
            title: i18n("Images and new containers")
            subtitle: i18n("Selected engine: %1", root.backend.engineBinary)
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing * 2
        Controls.TabBar {
            id:tabs;objectName:"deploymentTabs";Layout.fillWidth:true
            Components.SectionTabButton{text:i18n("Images")}
            Components.SectionTabButton{text:i18n("Deploy")}
            Components.SectionTabButton{text:i18n("Import")}
            Components.SectionTabButton{text:i18n("Storage")}
        }
        Controls.ScrollView {
            id:scroll;Layout.fillWidth:true;Layout.fillHeight:true;contentWidth:availableWidth
            ColumnLayout {
                width:scroll.availableWidth
                spacing:Kirigami.Units.smallSpacing*2
                ColumnLayout {
                    visible:tabs.currentIndex===0;Layout.fillWidth:true
                    Flow {
                        Layout.fillWidth:true;spacing:6
                        Components.ActionButton {text:root.searchExpanded?i18n("Hide image controls"):i18n("Show image controls");glyph:root.searchExpanded?"go-up":"go-down";onClicked:root.searchExpanded=!root.searchExpanded}
                        Controls.ComboBox {model:[i18n("Most stars"),i18n("Most downloads"),i18n("Name")];currentIndex:root.searchOrder;onActivated:root.searchOrder=currentIndex}
                        Controls.CheckBox {text:i18n("Official");checked:root.officialOnly;onToggled:root.officialOnly=checked}
                    }
                    PlasmaComponents.Label {visible:root.searchExpanded;Layout.fillWidth:true;text:i18n("Search Docker Hub, or enter a fully qualified image from any registry.");wrapMode:Text.Wrap}
                    RowLayout {
                        Layout.fillWidth:true
                        visible:root.searchExpanded
                        Controls.TextField{id:query;Layout.fillWidth:true;placeholderText:i18n("Search Docker Hub");onAccepted:root.controller.search(text)}
                        Components.ActionButton {text:i18n("Popular");PlasmaComponents.ToolTip.text:i18n("Browse Docker Hub results ranked by downloads. Sorting applies to the first 50 returned images.");PlasmaComponents.ToolTip.visible:hovered;glyph:"view-sort-ascending";enabled:!root.controller.busy;onClicked:{query.text="";root.searchOrder=1;root.controller.search("__popular__")}}
                        Components.ActionButton {text:i18n("Search");glyph:"edit-find";enabled:!root.controller.busy && query.text.trim()!=="";onClicked:root.controller.search(query.text)}
                    }
                    ListView {
                        id: imageResults
                        Layout.fillWidth:true;Layout.preferredHeight:Math.min(260,Math.max(100,count*64));clip:true
                        model:root.sortedResults
                        PlasmaComponents.Label {
                            anchors.centerIn: parent
                            width: Math.max(0,parent.width - 24)
                            visible: imageResults.count === 0
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            color: root.controller.failed ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor
                            text: root.controller.busy ? i18n("Searching…") : root.controller.failed ? root.controller.message
                                : root.controller.searchPerformed ? i18n("No images match this search") : i18n("Search for an image to see results here")
                        }
                        delegate:Controls.ItemDelegate {
                            id:result;required property var modelData;width:ListView.view.width
                            background:Components.Card {interactive:true;hovered:result.hovered}
                            contentItem:ColumnLayout {
                                RowLayout {Layout.fillWidth:true;PlasmaComponents.Label {Layout.fillWidth:true;text:result.modelData.name;font.bold:true;color:Kirigami.Theme.linkColor;elide:Text.ElideRight}Components.Pill {visible:result.modelData.official===true;dense:true;variant:"outline";text:i18n("Official");tone:"ok";glyph:"badge-check"}}
                                Flow {
                                    Layout.fillWidth:true;spacing:8
                                    PlasmaComponents.Label {text:"★ "+result.modelData.stars;color:Kirigami.Theme.neutralTextColor}
                                    PlasmaComponents.Label {text:i18n("↓ %1 downloads",result.modelData.pulls===null||result.modelData.pulls===undefined?i18n("Unavailable"):Number(result.modelData.pulls).toLocaleString());color:Kirigami.Theme.positiveTextColor}
                                    Components.ActionButton {text:i18n("Similar");glyph:"edit-find";onClicked:{query.text=result.modelData.name.split("/").pop();root.controller.search(query.text)}}
                                }
                                PlasmaComponents.Label {Layout.fillWidth:true;text:result.modelData.description;textFormat:Text.PlainText;maximumLineCount:2;wrapMode:Text.Wrap;elide:Text.ElideRight}
                            }
                            onClicked:root.useImage("docker.io/"+modelData.name)
                        }
                    }
                    RowLayout {
                        Layout.fillWidth:true
                        visible:root.searchExpanded
                        Controls.TextField{id:directImage;Layout.fillWidth:true;placeholderText:i18n("registry.example.com/image:tag")}
                        Components.ActionButton{text:i18n("Pull");glyph:"system-download";enabled:directImage.text.trim()!==""&&!root.backend.readOnly&&!root.controller.busy;onClicked:root.controller.pull(directImage.text)}
                        Components.ActionButton{text:i18n("Configure…");glyph:"package-upgrade";enabled:directImage.text.trim()!=="";onClicked:root.useImage(directImage.text)}
                    }
                }
                ColumnLayout {
                    visible:tabs.currentIndex===1;Layout.fillWidth:true;spacing:Kirigami.Units.smallSpacing*2
                    Kirigami.InlineMessage {Layout.fillWidth:true;visible:!root.controller.canDeploy;type:Kirigami.MessageType.Information;text:i18n("Project creation requires local Docker with Compose and write actions enabled. Image pulls remain available for other connected engines.")}
                    Kirigami.FormLayout {
                        Layout.fillWidth:true;wideMode:false
                        Controls.TextField{id:projectName;objectName:"deploymentProjectName";Kirigami.FormData.label:i18n("Project name:");Layout.fillWidth:true;placeholderText:"my-service"}
                        Controls.TextField{id:imageName;objectName:"deploymentImage";Kirigami.FormData.label:i18n("Image:");Layout.fillWidth:true;placeholderText:"nginx:alpine"}
                        Controls.ComboBox {
                            id:restart;Kirigami.FormData.label:i18n("Restart policy:");textRole:"label";valueRole:"value"
                            model:root.restartPolicies
                            Component.onCompleted:{var i=root.restartPolicies.findIndex(function(x){return x.value===root.backend.cfg.deploymentRestartPolicy});currentIndex=i<0?2:i}
                        }
                        Controls.TextArea{id:ports;Kirigami.FormData.label:i18n("Ports:");Layout.fillWidth:true;placeholderText:"127.0.0.1:8080:80\n8443:443";wrapMode:Text.Wrap}
                        Controls.TextArea{id:environment;Kirigami.FormData.label:i18n("Environment:");Layout.fillWidth:true;placeholderText:"TZ=Australia/Melbourne\nPUID=1000";wrapMode:Text.Wrap}
                        Controls.TextArea{id:mounts;Kirigami.FormData.label:i18n("Mounts:");Layout.fillWidth:true;placeholderText:"/host/folder:/data\nmy-volume:/config:ro";wrapMode:Text.Wrap}
                        Controls.CheckBox{id:managedData;Kirigami.FormData.label:i18n("Data folder:");text:i18n("Create a folder in my default storage directory")}
                        Controls.TextField{id:dataTarget;visible:managedData.checked;Kirigami.FormData.label:i18n("Mount inside container:");text:"/data";Layout.fillWidth:true}
                        Controls.TextField{id:network;Kirigami.FormData.label:i18n("Network:");text:root.backend.cfg.deploymentNetwork||"";placeholderText:i18n("Default Compose network");Layout.fillWidth:true}
                        Controls.TextField{id:command;Kirigami.FormData.label:i18n("Container command:");Layout.fillWidth:true;placeholderText:i18n("Optional executable and arguments")}
                        Controls.CheckBox{id:startNow;Kirigami.FormData.label:i18n("After creating:");text:i18n("Start the container");checked:true}
                    }
                    PlasmaComponents.Label {Layout.fillWidth:true;text:i18n("Project folder: %1/%2",root.controller.projectRoot,projectName.text||i18n("project-name"));wrapMode:Text.WrapAnywhere}
                    PlasmaComponents.Label {Layout.fillWidth:true;text:i18n("One port, environment variable, or mount per line. Named volumes are created or reused. Custom networks must already exist. Existing project files are never overwritten.");wrapMode:Text.Wrap}
                }
                ColumnLayout {
                    visible:tabs.currentIndex===2;Layout.fillWidth:true
                    PlasmaComponents.Label {Layout.fillWidth:true;text:i18n("Paste a docker run command to fill the deployment form. It is parsed into a Compose project and is never executed as a host shell command. Unsupported flags are reported.");wrapMode:Text.Wrap}
                    Controls.TextArea{id:importText;objectName:"deploymentImport";Layout.fillWidth:true;Layout.preferredHeight:180;placeholderText:"docker run -d --name my-app -p 8080:80 nginx:alpine";wrapMode:Text.WrapAnywhere}
                    Components.ActionButton{text:i18n("Import into form");glyph:"document-open";onClicked:root.importCommand()}
                }
                ColumnLayout {
                    visible:tabs.currentIndex===3;Layout.fillWidth:true
                    PlasmaComponents.Label {Layout.fillWidth:true;text:i18n("Create named volumes or networks on the selected engine. Docker manages volume storage; bind-mount folders are chosen in the deployment form.");wrapMode:Text.Wrap}
                    Kirigami.FormLayout {
                        Layout.fillWidth:true;wideMode:false
                        Controls.TextField{id:volumeName;Kirigami.FormData.label:i18n("Named volume:");Layout.fillWidth:true;placeholderText:"app-data"}
                        Components.ActionButton{text:i18n("Create volume");glyph:"drive-harddisk";enabled:!root.backend.readOnly&&!root.controller.busy&&volumeName.text.trim()!=="";onClicked:root.controller.createResource("volume",volumeName.text.trim())}
                        Controls.TextField{id:networkName;Kirigami.FormData.label:i18n("Network:");Layout.fillWidth:true;placeholderText:"apps"}
                        Components.ActionButton{text:i18n("Create network");glyph:"network-server";enabled:!root.backend.readOnly&&!root.controller.busy&&networkName.text.trim()!=="";onClicked:root.controller.createResource("network",networkName.text.trim())}
                    }
                    PlasmaComponents.Label {Layout.fillWidth:true;text:i18n("Configure default project folders, bind-mount storage and registry under Settings → Storage. Image layers stay in the engine's storage location.");wrapMode:Text.Wrap}
                }
            }
        }
        Kirigami.InlineMessage {Layout.fillWidth:true;visible:root.formError!=="";type:Kirigami.MessageType.Error;text:root.formError}
        Rectangle {
            objectName: "deploymentOutputResizeHandle"
            Layout.fillWidth: true
            Layout.preferredHeight: 5
            color: resizeHandle.containsMouse || resizeHandle.pressed
                ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.border)
            PlasmaComponents.ToolTip { visible: resizeHandle.containsMouse; text: i18n("Drag to resize command output") }
            MouseArea {
                id: resizeHandle
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.SizeVerCursor
                property real startSceneY: 0
                property int startHeight: 0
                onPressed: function(mouse) { startSceneY = mapToItem(null, mouse.x, mouse.y).y; startHeight = root.outputPanelHeight }
                onPositionChanged: function(mouse) {
                    if (pressed) root.outputPanelHeight = Math.max(64, Math.min(250, startHeight + startSceneY - mapToItem(null, mouse.x, mouse.y).y))
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents.Label { text: i18n("Command output"); font.bold: true }
            PlasmaComponents.BusyIndicator { visible: root.controller.busy; running: visible; implicitWidth: 18; implicitHeight: 18 }
            PlasmaComponents.Label { Layout.fillWidth: true; text: root.controller.message || (root.controller.busy ? i18n("Running…") : i18n("Ready")); color: root.controller.failed ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor; elide: Text.ElideRight }
            Components.ActionButton { text: root.outputPanelExpanded ? i18n("Hide") : i18n("Show"); glyph: root.outputPanelExpanded ? "chevron-down" : "chevron-up"; onClicked: root.outputPanelExpanded = !root.outputPanelExpanded }
            Components.ActionButton { text: i18n("Edit options"); glyph: "pencil"; visible: tabs.currentIndex !== 1; onClicked: { tabs.currentIndex = 1; root.formError = "" } }
        }
        Controls.ScrollView {
            objectName: "deploymentCommandOutput"
            Layout.fillWidth: true
            Layout.preferredHeight: root.outputPanelExpanded ? root.outputPanelHeight : 0
            visible: root.outputPanelExpanded
            clip: true
            Controls.TextArea {
                text: root.controller.output || root.controller.message || i18n("Search for an image or configure a deployment to see command output here.")
                readOnly: true
                wrapMode: Text.WrapAnywhere
                selectByMouse: true
                color: root.controller.failed ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
            }
        }
        RowLayout {
            Layout.fillWidth:true
            PlasmaComponents.BusyIndicator{visible:root.controller.busy;implicitWidth:22;implicitHeight:22}
            Item{Layout.fillWidth:true}
            Components.DockButton{variant:"primary";text:i18n("Review deployment…");glyph:"package-check";visible:tabs.currentIndex===1;enabled:root.controller.canDeploy&&!root.controller.busy;onClicked:root.review()}
        }
        }
    }
    Connections {target:root.backend;function onGenerationChanged(){reviewDialog.close();root.reviewed=null}}
    Controls.Dialog {
        id:reviewDialog
        parent:Controls.Overlay.overlay
        anchors.centerIn:parent
        width:Math.min(parent?parent.width-40:620,680)
        height:Math.min(parent?parent.height-40:600,650)
        modal:true;title:i18n("Review new project")
        standardButtons:Controls.Dialog.Ok|Controls.Dialog.Cancel
        onOpened:standardButton(Controls.Dialog.Ok).text=startNow.checked?i18n("Create and start"):i18n("Create stopped")
        onAccepted:if(root.reviewed)root.controller.create(root.reviewed,startNow.checked)
        contentItem:ColumnLayout {
            PlasmaComponents.Label{Layout.fillWidth:true;text:root.reviewed?i18n("Engine: %1\nProject: %2\nThe image will be pulled. %3",root.reviewed.engine,root.reviewed.directory,startNow.checked?i18n("The container will start."):i18n("The container will remain stopped.")):"";wrapMode:Text.Wrap}
            Controls.ScrollView{Layout.fillWidth:true;Layout.fillHeight:true;Controls.TextArea{text:root.reviewed?root.reviewed.json:"";readOnly:true;wrapMode:Text.WrapAnywhere;selectByMouse:true}}
        }
    }
}
