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
    signal openDetail(string recordId, int tab)
    /* The container the last create produced, once a refresh lists it. */
    readonly property var created: {
        const revision = root.backend.revision
        if (root.controller.activity !== "create" || root.controller.busy || root.controller.lastProject === "") return null
        return root.backend.records.find(function (r) { return r.project === root.controller.lastProject && r.state !== "not-created" }) || null
    }
    /* Created, Running and Healthy are different outcomes; a finished command implies none of them. */
    readonly property string createdState: {
        if (!root.created) return root.controller.lastCreated ? i18n("Created · waiting for the container list") : ""
        const health = String(root.created.health || "")
        if (root.created.state === "running")
            return health === "healthy" ? i18n("Running · healthy") : health === "starting" ? i18n("Running · health check starting")
                : health === "unhealthy" ? i18n("Running · unhealthy") : i18n("Running")
        if (root.created.state === "exited" && root.controller.lastStarted) return i18n("Exited right after starting: check its logs")
        return root.created.state === "created" ? i18n("Created, not started") : root.created.state
    }
    readonly property var controller: backend.deployment
    readonly property var restartPolicies: [{label:i18n("Manual start"),value:"no"},{label:i18n("On failure"),value:"on-failure"},{label:i18n("Unless stopped"),value:"unless-stopped"},{label:i18n("Always"),value:"always"}]
    property var reviewed: null
    property var importedOptions: ({})
    property string formError: ""
    property bool searchExpanded: true
    property bool directExpanded: false
    property int searchOrder: 0
    property bool officialOnly: false
    readonly property var sortedResults: controller.results.filter(function(r){return !root.officialOnly || r.official}).slice().sort(function(a,b){return root.searchOrder===0 ? Number(b.stars)-Number(a.stars) : root.searchOrder===1 ? Number(b.pulls||0)-Number(a.pulls||0) : String(a.name).localeCompare(String(b.name))})
    property int outputPanelHeight: 112
    property bool outputPanelExpanded: false
    /* Popup or dock narrower than the toolbars: buttons drop their labels. */
    readonly property bool narrow: width < Kirigami.Units.gridUnit * 24
    // Searches report into the results themselves; commands open the output.
    Connections { target: root.controller; function onBusyChanged() { if (root.controller.busy && root.controller.activity !== "search") root.outputPanelExpanded = true } }
    /* 2372530000 -> "2.4B": Number.toLocaleString() prints large counts in exponent form. */
    function compactCount(value) {
        const n = Number(value)
        if (!isFinite(n)) return i18n("Unavailable")
        const units = [[1e9, "B"], [1e6, "M"], [1e3, "k"]]
        for (let i = 0; i < units.length; i++)
            if (n >= units[i][0]) return (n / units[i][0]).toFixed(n >= units[i][0] * 10 ? 0 : 1) + units[i][1]
        return String(Math.round(n))
    }
    objectName: "deploymentPage"

    /* A labelled form field: the label above, an optional hint below. */
    component Field: ColumnLayout {
        id: field
        property string label: ""
        property string hint: ""
        default property alias content: slot.data
        Layout.fillWidth: true
        Layout.margins: Kirigami.Units.smallSpacing
        spacing: 2
        PlasmaComponents.Label { text: field.label; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor }
        ColumnLayout { id: slot; Layout.fillWidth: true; spacing: 0 }
        PlasmaComponents.Label { visible: field.hint !== ""; Layout.fillWidth: true; text: field.hint; font: Kirigami.Theme.smallFont; opacity: 0.7; wrapMode: Text.WrapAnywhere }
    }

    function show(tab) { if (tab !== undefined) tabs.currentIndex = tab; root.visible = true }
    function close() { root.closeRequested() }
    onInitialTabChanged: if (tabs) tabs.currentIndex = root.initialTab
    function input() {
        return Object.assign({}, importedOptions, {name:projectName.text,image:imageName.text,ports:ports.text,mounts:mounts.text,environment:environment.text,command:command.text,network:network.text,restart:restart.currentValue,managedData:managedData.checked,dataTarget:dataTarget.text})
    }
    /* The form as typed, without imported options (they come back with the fields). */
    function formState() {
        return {name:projectName.text,image:imageName.text,ports:ports.text,mounts:mounts.text,environment:environment.text,command:command.text,
                network:network.text,restart:restart.currentIndex,managedData:managedData.checked,dataTarget:dataTarget.text,startNow:startNow.checked,
                imported:importedOptions}
    }
    readonly property bool formTouched: projectName.text !== "" || imageName.text !== "" || ports.text !== "" || mounts.text !== ""
        || environment.text !== "" || command.text !== ""
    function restoreDraft(d) {
        projectName.text=d.name;imageName.text=d.image;ports.text=d.ports;mounts.text=d.mounts;environment.text=d.environment;command.text=d.command
        network.text=d.network;restart.currentIndex=d.restart;managedData.checked=d.managedData;dataTarget.text=d.dataTarget;startNow.checked=d.startNow
        importedOptions=d.imported||({})
    }
    function discardDraft() {
        controller.draft=null
        projectName.text="";imageName.text="";ports.text="";mounts.text="";environment.text="";command.text="";importedOptions=({});formError=""
        network.text=root.backend.cfg.deploymentNetwork||""
    }
    // Keep what is typed as it changes, so closing the page cannot lose it, and
    // restore it when the page opens again. Saving starts after the restore.
    property bool draftReady: false
    readonly property var liveDraft: root.formTouched ? root.formState() : null
    onLiveDraftChanged: if (root.draftReady && controller) controller.draft = root.liveDraft
    Component.onCompleted: Qt.callLater(function () {
        if (controller && controller.draft) root.restoreDraft(controller.draft)
        root.draftReady = true
    })
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
            title: i18n("Deploy")
            subtitle: i18n("Find an image, configure a container and deploy it · %1", root.backend.engineBinary)
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing * 2
        Controls.TabBar {
            id:tabs;objectName:"deploymentTabs";Layout.fillWidth:true;spacing:Kirigami.Units.smallSpacing;background:null
            Components.SectionTabButton{text:i18n("Find Image")}
            Components.SectionTabButton{text:i18n("Configure")}
            Components.SectionTabButton{text:i18n("Import")}
            Components.SectionTabButton{text:i18n("Storage")}
        }
        Controls.ScrollView {
            id:scroll;Layout.fillWidth:true;Layout.fillHeight:true;contentWidth:availableWidth
            ColumnLayout {
                width:scroll.availableWidth
                spacing:Kirigami.Units.smallSpacing*2
                ColumnLayout {
                    visible:tabs.currentIndex===0;Layout.fillWidth:true;spacing:Kirigami.Units.smallSpacing
                    RowLayout {
                        Layout.fillWidth:true;spacing:Kirigami.Units.smallSpacing
                        Components.DockTab {glyph:"search";text:i18n("Search Docker Hub");checked:!root.directExpanded;onClicked:root.directExpanded=false}
                        Components.DockTab {glyph:"box";text:i18n("A specific image");checked:root.directExpanded;onClicked:root.directExpanded=true}
                        Item {Layout.fillWidth:true}
                    }
                    RowLayout {
                        visible:!root.directExpanded
                        Layout.fillWidth:true;spacing:Kirigami.Units.smallSpacing
                        Controls.TextField{id:query;Layout.fillWidth:true;placeholderText:i18n("Search Docker Hub…");onAccepted:root.controller.search(text)}
                        Components.DockButton{variant:"primary";text:i18n("Search");glyph:"search";iconOnly:root.narrow;enabled:!root.controller.busy && query.text.trim()!=="";onClicked:root.controller.search(query.text)}
                    }
                    RowLayout {
                        visible:!root.directExpanded
                        Layout.fillWidth:true;spacing:Kirigami.Units.smallSpacing
                        Components.DockButton {variant:"flat";text:i18n("Popular");glyph:"trending-up";iconOnly:root.narrow;iconTone:"orange";PlasmaComponents.ToolTip.text:i18n("Browse Docker Hub results ranked by downloads. Sorting applies to the first 50 returned images.");PlasmaComponents.ToolTip.visible:hovered;enabled:!root.controller.busy;onClicked:{query.text="";root.searchOrder=1;root.controller.search("__popular__")}}
                        Components.DockButton {variant:"flat";checkable:true;checked:root.officialOnly;iconOnly:root.narrow;text:i18n("Official only");glyph:"badge-check";iconTone:"emerald";onClicked:root.officialOnly=checked}
                        Item {Layout.fillWidth:true}
                        PlasmaComponents.Label {visible:!root.narrow;text:i18n("Sort");font:Kirigami.Theme.smallFont;color:Kirigami.Theme.disabledTextColor}
                        Controls.ComboBox {Layout.maximumWidth:Kirigami.Units.gridUnit*9;Layout.minimumWidth:Kirigami.Units.gridUnit*5;Layout.fillWidth:root.narrow;model:[i18n("Most stars"),i18n("Most downloads"),i18n("Name")];currentIndex:root.searchOrder;onActivated:root.searchOrder=currentIndex}
                    }
                    PlasmaComponents.Label {
                        objectName: "imageSearchStatus"
                        visible: !root.directExpanded
                        Layout.fillWidth: true
                        Layout.topMargin: imageResults.count > 0 ? 0 : Kirigami.Units.gridUnit
                        horizontalAlignment: imageResults.count > 0 ? Text.AlignLeft : Text.AlignHCenter
                        wrapMode: Text.Wrap
                        font: imageResults.count > 0 ? Kirigami.Theme.smallFont : Kirigami.Theme.defaultFont
                        color: root.controller.failed && root.controller.activity === "search" ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor
                        text: root.controller.busy && root.controller.activity === "search" ? i18n("Searching…")
                            : root.controller.failed && root.controller.activity === "search" ? root.controller.message
                            : imageResults.count > 0 ? i18np("%1 image · click one to set it up", "%1 images · click one to set it up", imageResults.count)
                            : root.controller.searchPerformed ? i18n("No images match this search") : i18n("Search Docker Hub, or choose “A specific image” above.")
                    }
                    GridLayout {
                        id: resultGrid
                        objectName: "imageResults"
                        visible: !root.directExpanded && imageResults.count > 0
                        Layout.fillWidth: true
                        // Two cards side by side once each has room for a name and its counts.
                        columns: width >= Kirigami.Units.gridUnit * 28 ? 2 : 1
                        columnSpacing: Kirigami.Units.smallSpacing
                        rowSpacing: Kirigami.Units.smallSpacing
                        uniformCellWidths: true
                        Repeater {
                            id: imageResults
                            model: root.sortedResults
                            delegate: Controls.ItemDelegate {
                                id: result
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: 1
                                padding: Kirigami.Units.smallSpacing * 2
                                background: Components.Card { interactive: true; hovered: result.hovered }
                                PlasmaComponents.ToolTip.text: i18n("Set up a container from %1", result.modelData.name)
                                PlasmaComponents.ToolTip.visible: hovered
                                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                                contentItem: ColumnLayout {
                                    spacing: Kirigami.Units.smallSpacing
                                    RowLayout {
                                        Layout.fillWidth: true
                                        // Same height with or without the Official badge.
                                        Layout.minimumHeight: Kirigami.Units.gridUnit * 1.05
                                        spacing: Kirigami.Units.smallSpacing
                                        PlasmaComponents.Label { Layout.fillWidth: true; text: result.modelData.name; font.bold: true; color: Kirigami.Theme.linkColor; elide: Text.ElideMiddle }
                                        Components.Pill { visible: result.modelData.official === true; dense: true; variant: "outline"; text: i18n("Official"); tone: "ok"; glyph: "badge-check" }
                                    }
                                    PlasmaComponents.Label {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.minimumHeight: lineMetrics.height * 2
                                        verticalAlignment: Text.AlignTop
                                        text: result.modelData.description || i18n("No description")
                                        textFormat: Text.PlainText
                                        maximumLineCount: 2
                                        wrapMode: Text.Wrap
                                        elide: Text.ElideRight
                                        opacity: result.modelData.description ? Style.TEXT.strong : Style.TEXT.soft
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Kirigami.Units.largeSpacing
                                        PlasmaComponents.Label { text: "★ " + root.compactCount(result.modelData.stars); color: Kirigami.Theme.neutralTextColor; font: Kirigami.Theme.smallFont }
                                        PlasmaComponents.Label {
                                            text: result.modelData.pulls === null || result.modelData.pulls === undefined ? i18n("↓ unavailable") : "↓ " + root.compactCount(result.modelData.pulls)
                                            color: Kirigami.Theme.positiveTextColor
                                            font: Kirigami.Theme.smallFont
                                            PlasmaComponents.ToolTip.text: i18n("%1 downloads", Number(result.modelData.pulls || 0).toLocaleString(Qt.locale(), "f", 0))
                                            PlasmaComponents.ToolTip.visible: pullsHover.hovered
                                            HoverHandler { id: pullsHover }
                                        }
                                        Item { Layout.fillWidth: true }
                                        Components.ActionButton { text: i18n("Similar"); glyph: "edit-find"; iconOnly: root.narrow; onClicked: { query.text = result.modelData.name.split("/").pop(); root.controller.search(query.text) } }
                                    }
                                }
                                onClicked: root.useImage("docker.io/" + modelData.name)
                            }
                        }
                    }
                    FontMetrics { id: lineMetrics; font: Kirigami.Theme.defaultFont }
                    PlasmaComponents.Label {
                        visible:root.directExpanded
                        Layout.fillWidth:true
                        text:i18n("Pull an image you already know the name of, from any registry. Use a fully qualified name such as registry.example.com/image:tag.")
                        wrapMode:Text.Wrap
                        color:Kirigami.Theme.disabledTextColor
                    }
                    RowLayout {
                        Layout.fillWidth:true
                        visible:root.directExpanded
                        Controls.TextField{id:directImage;Layout.fillWidth:true;placeholderText:i18n("registry.example.com/image:tag")}
                        Components.DockButton{text:i18n("Pull");glyph:"cloud-download";enabled:directImage.text.trim()!==""&&!root.backend.readOnly&&!root.controller.busy;onClicked:root.controller.pull(directImage.text)}
                        Components.DockButton{text:i18n("Configure…");glyph:"settings-2";enabled:directImage.text.trim()!=="";onClicked:root.useImage(directImage.text)}
                    }
                }
                // ---- Configure: the form, in the same cards as a container's details ----
                ColumnLayout {
                    visible:tabs.currentIndex===1;Layout.fillWidth:true;spacing:Kirigami.Units.largeSpacing
                    Kirigami.InlineMessage {Layout.fillWidth:true;visible:!root.controller.canDeploy;type:Kirigami.MessageType.Information;text:i18n("Project creation requires local Docker with Compose and write actions enabled. Image pulls remain available for other connected engines.")}
                    GridLayout {
                        Layout.fillWidth:true
                        columns: width >= Kirigami.Units.gridUnit * 34 ? 2 : 1
                        columnSpacing: Kirigami.Units.largeSpacing
                        rowSpacing: Kirigami.Units.largeSpacing
                        uniformCellWidths: true
                        Components.Card {
                            Layout.fillWidth:true;Layout.fillHeight:true;Layout.preferredWidth:1
                            prominentTitle:true;title:i18n("Container");titleGlyph:"box";titleTone:"blue"
                            padding:Kirigami.Units.smallSpacing*2
                            Field { label:i18n("Project name"); hint:i18n("Folder: %1/%2", root.controller.projectRoot, projectName.text || i18n("project-name"))
                                Controls.TextField{id:projectName;objectName:"deploymentProjectName";Layout.fillWidth:true;placeholderText:"my-service"} }
                            Field { label:i18n("Image")
                                Controls.TextField{id:imageName;objectName:"deploymentImage";Layout.fillWidth:true;placeholderText:"nginx:alpine"} }
                            Field { label:i18n("Restart policy")
                                Controls.ComboBox {
                                    id:restart;Layout.fillWidth:true;textRole:"label";valueRole:"value"
                                    model:root.restartPolicies
                                    Component.onCompleted:{var i=root.restartPolicies.findIndex(function(x){return x.value===root.backend.cfg.deploymentRestartPolicy});currentIndex=i<0?2:i}
                                } }
                            Field { label:i18n("Command"); hint:i18n("Optional; replaces the image's default command.")
                                Controls.TextField{id:command;Layout.fillWidth:true;placeholderText:i18n("Executable and arguments")} }
                        }
                        Components.Card {
                            Layout.fillWidth:true;Layout.fillHeight:true;Layout.preferredWidth:1
                            prominentTitle:true;title:i18n("Network");titleGlyph:"network";titleTone:"violet"
                            padding:Kirigami.Units.smallSpacing*2
                            Field { label:i18n("Ports"); hint:i18n("One per line: [address:]host:container")
                                Controls.TextArea{id:ports;Layout.fillWidth:true;Layout.preferredHeight:Kirigami.Units.gridUnit*4;placeholderText:"127.0.0.1:8080:80\n8443:443";wrapMode:Text.Wrap} }
                            Field { label:i18n("Network"); hint:i18n("Custom networks must already exist.")
                                Controls.TextField{id:network;text:root.backend.cfg.deploymentNetwork||"";placeholderText:i18n("Default Compose network");Layout.fillWidth:true} }
                        }
                        Components.Card {
                            Layout.fillWidth:true;Layout.fillHeight:true;Layout.preferredWidth:1
                            prominentTitle:true;title:i18n("Environment");titleGlyph:"sliders-horizontal";titleTone:"teal"
                            padding:Kirigami.Units.smallSpacing*2
                            Field { label:i18n("Variables"); hint:i18n("One NAME=value per line.")
                                Controls.TextArea{id:environment;Layout.fillWidth:true;Layout.preferredHeight:Kirigami.Units.gridUnit*4;placeholderText:"TZ=Australia/Melbourne\nPUID=1000";wrapMode:Text.Wrap} }
                        }
                        Components.Card {
                            Layout.fillWidth:true;Layout.fillHeight:true;Layout.preferredWidth:1
                            prominentTitle:true;title:i18n("Storage");titleGlyph:"hard-drive";titleTone:"amber"
                            padding:Kirigami.Units.smallSpacing*2
                            Field { label:i18n("Mounts"); hint:i18n("One per line. Named volumes are created or reused.")
                                Controls.TextArea{id:mounts;Layout.fillWidth:true;Layout.preferredHeight:Kirigami.Units.gridUnit*4;placeholderText:"/host/folder:/data\nmy-volume:/config:ro";wrapMode:Text.Wrap} }
                            Controls.CheckBox{id:managedData;Layout.leftMargin:Kirigami.Units.largeSpacing;text:i18n("Create a data folder in my storage directory")}
                            Field { visible:managedData.checked; label:i18n("Mount the data folder at")
                                Controls.TextField{id:dataTarget;text:"/data";Layout.fillWidth:true} }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth:true
                        spacing:Kirigami.Units.largeSpacing
                        Controls.CheckBox{id:startNow;text:i18n("Start the container after creating it");checked:true}
                        Components.DockButton{visible:root.formTouched;glyph:"eraser";text:i18n("Discard Draft");onClicked:root.discardDraft()
                            PlasmaComponents.ToolTip.text:i18n("Clear the form. Drafts are kept only while Plasma runs and never saved to disk.");PlasmaComponents.ToolTip.visible:hovered;PlasmaComponents.ToolTip.delay:Kirigami.Units.toolTipDelay}
                        PlasmaComponents.Label {Layout.fillWidth:true;text:i18n("Existing project files are never overwritten.");wrapMode:Text.Wrap;font:Kirigami.Theme.smallFont;color:Kirigami.Theme.disabledTextColor}
                    }
                }
                // ---- Import: a docker run command into the form ----
                Components.Card {
                    visible:tabs.currentIndex===2;Layout.fillWidth:true
                    prominentTitle:true;title:i18n("Import a docker run Command");titleGlyph:"square-terminal";titleTone:"cyan"
                    padding:Kirigami.Units.smallSpacing*2
                    PlasmaComponents.Label {Layout.fillWidth:true;Layout.margins:Kirigami.Units.smallSpacing;text:i18n("Paste a docker run command to fill the Configure form. It is parsed into a Compose project and never executed as a shell command. Unsupported flags are reported.");wrapMode:Text.Wrap;color:Kirigami.Theme.disabledTextColor}
                    Controls.TextArea{id:importText;objectName:"deploymentImport";Layout.fillWidth:true;Layout.margins:Kirigami.Units.smallSpacing;Layout.preferredHeight:180;placeholderText:"docker run -d --name my-app -p 8080:80 nginx:alpine";wrapMode:Text.WrapAnywhere;font.family:Kirigami.Theme.fixedWidthFont.family}
                    RowLayout {
                        Layout.fillWidth:true;Layout.margins:Kirigami.Units.smallSpacing
                        Item{Layout.fillWidth:true}
                        Components.DockButton{variant:"primary";text:i18n("Fill the Form");glyph:"document-open";enabled:importText.text.trim()!=="";onClicked:root.importCommand()}
                    }
                }
                // ---- Storage: named volumes and networks ----
                ColumnLayout {
                    visible:tabs.currentIndex===3;Layout.fillWidth:true;spacing:Kirigami.Units.largeSpacing
                    GridLayout {
                        Layout.fillWidth:true
                        columns: width >= Kirigami.Units.gridUnit * 34 ? 2 : 1
                        columnSpacing: Kirigami.Units.largeSpacing
                        rowSpacing: Kirigami.Units.largeSpacing
                        uniformCellWidths: true
                        Components.Card {
                            Layout.fillWidth:true;Layout.fillHeight:true;Layout.preferredWidth:1
                            prominentTitle:true;title:i18n("Named Volume");titleGlyph:"database";titleTone:"amber"
                            padding:Kirigami.Units.smallSpacing*2
                            Field { label:i18n("Name"); hint:i18n("Docker keeps its contents in its own data directory.")
                                RowLayout { Layout.fillWidth:true
                                    Controls.TextField{id:volumeName;Layout.fillWidth:true;placeholderText:"app-data"}
                                    Components.DockButton{text:i18n("Create");glyph:"list-add";enabled:!root.backend.readOnly&&!root.controller.busy&&volumeName.text.trim()!=="";onClicked:root.controller.createResource("volume",volumeName.text.trim())} } }
                        }
                        Components.Card {
                            Layout.fillWidth:true;Layout.fillHeight:true;Layout.preferredWidth:1
                            prominentTitle:true;title:i18n("Network");titleGlyph:"network";titleTone:"violet"
                            padding:Kirigami.Units.smallSpacing*2
                            Field { label:i18n("Name"); hint:i18n("Containers on the same network reach each other by name.")
                                RowLayout { Layout.fillWidth:true
                                    Controls.TextField{id:networkName;Layout.fillWidth:true;placeholderText:"apps"}
                                    Components.DockButton{text:i18n("Create");glyph:"list-add";enabled:!root.backend.readOnly&&!root.controller.busy&&networkName.text.trim()!=="";onClicked:root.controller.createResource("network",networkName.text.trim())} } }
                        }
                    }
                    PlasmaComponents.Label {Layout.fillWidth:true;text:i18n("Default project folders, bind-mount storage and the registry are set under Settings → Storage.");wrapMode:Text.Wrap;font:Kirigami.Theme.smallFont;color:Kirigami.Theme.disabledTextColor}
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
        // After a create: what now exists and the next useful step. On failure the
        // project files stay where they were written, so offer those instead.
        Components.Card {
            objectName: "deploymentResult"
            Layout.fillWidth: true
            visible: root.controller.activity === "create" && !root.controller.busy && root.controller.lastProject !== ""
                && (root.controller.lastCreated || root.controller.failed)
            tone: root.controller.failed ? "bad" : root.created && root.created.state === "running" ? "ok" : ""
            padding: Kirigami.Units.smallSpacing * 1.5
            ColumnLayout {
                spacing: Kirigami.Units.smallSpacing
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    font.bold: true
                    elide: Text.ElideRight
                    text: root.controller.failed ? i18n("%1 was not created", root.controller.lastProject) : root.controller.lastProject
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                    text: root.controller.failed ? i18n("Its project files are kept in %1. Fix the options and review again, or remove the folder.", root.controller.lastFolder)
                        : root.createdState
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    Components.DockButton { visible: !!root.created; glyph: "badge-info"; text: i18n("Details"); onClicked: root.openDetail(root.created.id, 0) }
                    Components.DockButton { visible: !!root.created; glyph: "scroll-text"; text: i18n("Logs"); onClicked: root.openDetail(root.created.id, 1) }
                    Components.DockButton {
                        readonly property var links: root.created && root.created.state === "running" ? root.backend.linksFor(root.created) : []
                        visible: links.length > 0
                        glyph: "globe"; text: i18n("Web")
                        onClicked: root.backend.openLink(links[0])
                    }
                    Components.DockButton {
                        visible: root.controller.lastFolder !== "" && !root.backend.remoteEngine
                        glyph: "folder-open"; text: i18n("Project Folder")
                        onClicked: Qt.openUrlExternally("file://" + root.controller.lastFolder)
                    }
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
            PlasmaComponents.BusyIndicator{visible:root.controller.busy;running:visible;implicitWidth:22;implicitHeight:22}
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
