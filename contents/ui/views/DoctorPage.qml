import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../components" as Components
import "../../lib/style.js" as Style

Item {
    id: root
    objectName: "doctorPage"
    required property var backend
    /* True when shown inside the main page's dock. */
    property bool embedded: false
    required property var dialogs
    readonly property var doctor: backend.doctor
    property int tab: 0
    property string initialCleanup: ""
    property int selectedIndex: 0
    readonly property var record: backend.records[Math.max(0,Math.min(selectedIndex,backend.records.length-1))] || null
    readonly property var inspected: record ? doctor.checks[record.id] || {} : {}
    readonly property var visibleFindings: doctor.findings.filter(function(f){return root.tab===0&&(f.kind==="overview"||f.kind==="containers") || root.tab===1&&f.kind==="containers" || root.tab===2&&f.kind==="compose"})
    signal openDetail(string recordId, int initialTab)
    signal openResources()
    function openUrl(url) { if(doctor.validUrl(url))Qt.openUrlExternally(url) }
    function findingSeverity(finding) { return finding.severity || "info" }
    function findingColor(finding) {
        const severity = root.findingSeverity(finding)
        if (severity === "error") return Kirigami.Theme.negativeTextColor
        if (severity === "warning") return Kirigami.Theme.neutralTextColor
        return Kirigami.Theme.linkColor
    }
    function findingGlyph(finding) {
        const severity = root.findingSeverity(finding)
        if (severity === "error") return "circle-x"
        if (severity === "warning") return "dialog-warning"
        return "document-view"
    }
    // Nothing runs on open: the insights come from state already known. Checks start with the button.
    Component.onCompleted: {if(initialCleanup){doctor.scan(false);doctor.cleanupPlan(initialCleanup)}}

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Components.PageHeader {
            compact: root.embedded
            title: i18n("Doctor")
            subtitle: doctor.checkedAt ? i18n("Checked %1", new Date(doctor.checkedAt).toLocaleTimeString()) : i18n("Not checked yet")
            Components.DockButton { variant: "primary"; glyph: "view-refresh"; text: i18n("Check"); enabled: !doctor.scanning && !doctor.executing; onClicked: doctor.scan() }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing
        Controls.ComboBox {
            Layout.fillWidth:true;visible:root.width<640
            Accessible.name:i18n("Doctor section")
            model:[i18n("Overview"),i18n("Containers"),i18n("Compose"),i18n("Storage"),i18n("About")]
            currentIndex:root.tab;onActivated:root.tab=currentIndex
        }
        Controls.TabBar {
            visible:root.width>=640;spacing:Kirigami.Units.smallSpacing;background:null
            Layout.fillWidth:true
            currentIndex:root.tab;onCurrentIndexChanged:root.tab=currentIndex
            Components.SectionTabButton {text:i18n("Overview")}
            Components.SectionTabButton {text:i18n("Containers")}
            Components.SectionTabButton {text:i18n("Compose")}
            Components.SectionTabButton {text:i18n("Storage")}
            Components.SectionTabButton {text:i18n("About")}
        }
        PlasmaComponents.Label {Layout.fillWidth:true;text:doctor.progress;visible:text!=="";wrapMode:Text.Wrap;font:Kirigami.Theme.smallFont}
        Controls.ScrollView {
            id: scroll
            Layout.fillWidth:true;Layout.fillHeight:true;contentWidth:availableWidth
            ColumnLayout {
                width:scroll.availableWidth
                spacing:Kirigami.Units.smallSpacing*2
                // Front page: what is already known, and the way to a full check.
                Components.Card {
                    Layout.fillWidth:true;visible:root.tab===0&&!doctor.checkedAt&&!doctor.scanning
                    prominentTitle:true;title:i18n("What Dockmoid Already Knows");titleGlyph:"lightbulb";titleTone:"blue"
                    PlasmaComponents.Label {
                        Layout.fillWidth:true;wrapMode:Text.WordWrap
                        visible:doctor.insights.length===0
                        text:i18n("Nothing stands out from the state Dockmoid already has. Run checks for a full look at the engine, the Compose projects and the storage.")
                    }
                    Repeater {
                        model:doctor.insights
                        delegate:RowLayout {
                            required property var modelData
                            Layout.fillWidth:true;spacing:Kirigami.Units.smallSpacing
                            Layout.alignment:Qt.AlignTop
                            Components.ActionIcon {
                                glyph:modelData.severity==="error"?"circle-x":modelData.severity==="warning"?"circle-alert":"info"
                                color:modelData.severity==="error"?Kirigami.Theme.negativeTextColor:modelData.severity==="warning"?Kirigami.Theme.neutralTextColor:Kirigami.Theme.disabledTextColor
                                implicitWidth:Kirigami.Units.iconSizes.small;implicitHeight:implicitWidth;Layout.alignment:Qt.AlignTop
                            }
                            ColumnLayout {
                                Layout.fillWidth:true;spacing:0
                                PlasmaComponents.Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;font.bold:true;text:modelData.title}
                                PlasmaComponents.Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;font:Kirigami.Theme.smallFont;color:Kirigami.Theme.disabledTextColor;text:modelData.detail;visible:text!==""}
                            }
                            Components.DockButton {
                                visible:modelData.id!==""
                                glyph:"stethoscope";text:i18n("Diagnose");iconOnly:true
                                onClicked:root.backend.diagnoseRequested(modelData.id)
                            }
                        }
                    }
                    Components.DockButton {
                        variant:"primary";glyph:"view-refresh";text:i18n("Run checks");enabled:!doctor.scanning&&!doctor.executing
                        onClicked:doctor.scan()
                    }
                }
                Flow {
                    Layout.fillWidth:true;visible:root.tab===0;spacing:Kirigami.Units.smallSpacing
                    Components.StatTile {clickable:false;glyph:"circle-play";value:backend.running;label:i18n("Running")}
                    Components.StatTile {clickable:false;glyph:"circle-pause";value:backend.stopped;label:i18n("Stopped")}
                    Components.StatTile {clickable:false;glyph:"circle-plus";value:backend.notCreated;label:i18n("Undeployed")}
                    Components.StatTile {clickable:false;glyph:"triangle-alert";value:backend.problemCount;label:i18n("Need attention")}
                }
                Controls.ComboBox {
                    Layout.fillWidth:true;visible:root.tab===1||root.tab===4
                    model:backend.records.map(function(r){return r.name+" · "+r.state});currentIndex:root.selectedIndex;onActivated:root.selectedIndex=currentIndex
                }
                ColumnLayout {
                    visible:root.tab===1&&!!root.record;Layout.fillWidth:true
                    PlasmaComponents.Label {Layout.fillWidth:true;wrapMode:Text.Wrap;text:root.record?root.record.name+" · "+root.record.status:"";font.bold:true}
                    Controls.TextArea {
                        Layout.fillWidth:true;readOnly:true;selectByMouse:true;wrapMode:TextEdit.Wrap
                        text:root.record?(root.record.state==="not-created"?i18n("No container exists. Health checks, logs and exit details are unavailable until it is created."):
                            Object.keys(root.inspected).length?JSON.stringify(root.inspected,null,2):i18n("Diagnostic details unavailable. Run Check to read state, health-check output, exit reason, restart count, ports, mounts and networks.")):""
                    }
                    Flow {
                        Layout.fillWidth:true;spacing:Kirigami.Units.smallSpacing
                        Components.ActionButton {text:i18n("Details");glyph:"document-view";onClicked:if(root.record)root.openDetail(root.record.id,0)}
                        Components.ActionButton {text:i18n("Logs");glyph:"text-x-generic";enabled:root.record&&root.record.state!=="not-created";onClicked:root.openDetail(root.record.id,1)}
                        Components.ActionButton {text:i18n("Preview start");glyph:"media-playback-start";enabled:root.record&&!root.record.isRunning&&!backend.readOnly;onClicked:doctor.addPlan(root.record,"start")}
                        Components.ActionButton {text:i18n("Preview restart");glyph:"view-refresh";enabled:root.record&&root.record.state!=="not-created"&&!backend.readOnly;onClicked:doctor.addPlan(root.record,"restart")}
                        Components.ActionButton {text:i18n("Preview pull");glyph:"system-download";enabled:!!root.record&&!backend.readOnly;onClicked:doctor.addPlan(root.record,"pull")}
                        Components.ActionButton {text:i18n("Preview recreate");glyph:"package-upgrade";enabled:root.record&&root.record.state!=="not-created"&&!!root.record.service&&backend.canUseCompose&&!backend.readOnly;onClicked:doctor.addPlan(root.record,"recreate")}
                    }
                }
                Repeater {
                    model:root.tab<=2?root.visibleFindings:[]
                    delegate: Rectangle {
                        id:finding
                        required property var modelData
                        Layout.fillWidth:true;implicitHeight:findingContent.implicitHeight+16
                        readonly property color severityColor: root.findingColor(modelData)
                        color:"transparent"
                        Components.Card { anchors.fill: parent; z: -1; tone: finding.modelData.severity === "error" ? "bad" : finding.modelData.severity === "warning" ? "warn" : "info" }
                        ColumnLayout {
                            id:findingContent;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:8;anchors.leftMargin:12
                            RowLayout {
                                Layout.fillWidth:true
                                Components.ActionIcon {glyph:root.findingGlyph(finding.modelData);color:finding.severityColor}
                                Components.Pill {dense:true;variant:"outline";text:finding.modelData.severity==="error"?i18n("Error"):finding.modelData.severity==="warning"?i18n("Warning"):i18n("Info");tone:finding.modelData.severity==="error"?"bad":finding.modelData.severity==="warning"?"amber":"blue"}
                                PlasmaComponents.Label {Layout.fillWidth:true;text:finding.modelData.title;font.bold:true;wrapMode:Text.Wrap;color:finding.severityColor}
                            }
                            PlasmaComponents.Label {Layout.fillWidth:true;text:finding.modelData.evidence;textFormat:Text.PlainText;wrapMode:Text.WrapAnywhere}
                            Flow {
                                Layout.fillWidth:true;spacing:Kirigami.Units.smallSpacing
                                Components.ActionButton {text:i18n("Evidence");glyph:"document-view";visible:finding.modelData.id!=="";onClicked:{const at=backend.records.findIndex(function(r){return r.id===finding.modelData.id});if(at>=0)root.selectedIndex=at;root.tab=1}}
                                Components.ActionButton {text:i18n("Logs");glyph:"text-x-generic";visible:finding.modelData.kind==="containers"&&finding.modelData.id!=="";onClicked:root.openDetail(finding.modelData.id,1)}
                                Components.ActionButton {text:i18n("Diagnose");glyph:"stethoscope";visible:finding.modelData.kind==="containers"&&finding.modelData.id!=="";onClicked:root.backend.diagnoseRequested(finding.modelData.id)}
                                Components.ActionButton {text:i18n("Preview fix");glyph:"document-properties";visible:finding.modelData.action!=="";enabled:!backend.readOnly;onClicked:doctor.addPlan(backend.findRecord(finding.modelData.id),finding.modelData.action)}
                                Components.ActionButton {text:i18n("Documentation");glyph:"insert-link";onClicked:root.openUrl(finding.modelData.help)}
                            }
                        }
                    }
                }
                PlasmaComponents.Label {Layout.fillWidth:true;visible:root.tab<=2&&root.visibleFindings.length===0&&(doctor.checkedAt>0||doctor.scanning||root.tab>0);text:doctor.scanning?i18n("Checks in progress…"):i18n("No findings in this section. This is a point-in-time check, not a guarantee of service health.");wrapMode:Text.Wrap}
                ColumnLayout {
                    Layout.fillWidth:true;visible:root.tab===3
                    PlasmaComponents.Label {text:i18n("Engine-reported disk usage");font.bold:true}
                    Repeater {model:backend.diskUsage;delegate:PlasmaComponents.Label {required property var modelData;Layout.fillWidth:true;wrapMode:Text.Wrap;text:modelData.type+" · "+modelData.size+" · "+i18n("Reclaimable: %1",modelData.reclaimable||i18n("Unavailable"))}}
                    PlasmaComponents.Label {Layout.fillWidth:true;visible:!backend.diskUsageKnown;text:i18n("Disk usage unavailable. Check the engine connection and run Check.");wrapMode:Text.Wrap}
                    Flow {
                        Layout.fillWidth:true;spacing:Kirigami.Units.smallSpacing
                        Components.ActionButton {text:i18n("Resources");glyph:"drive-harddisk";onClicked:root.openResources()}
                        Components.ActionButton {text:i18n("Preview dangling images");glyph:"edit-delete";enabled:!backend.readOnly&&!backend.isPodman;onClicked:doctor.cleanupPlan("images")}
                        Components.ActionButton {text:i18n("Preview build cache");glyph:"edit-delete";enabled:!backend.readOnly&&!backend.isPodman;onClicked:doctor.cleanupPlan("cache")}
                        Components.ActionButton {text:i18n("Review other cleanup…");glyph:"configure";enabled:!backend.readOnly&&!backend.isPodman;onClicked:dialogs.confirmPrune()}
                    }
                    PlasmaComponents.Label {Layout.fillWidth:true;text:i18n("Compose references are intentions, not existing-container usage. Review referenced images before removal. Default cleanup retains stopped containers, networks and volumes.");wrapMode:Text.Wrap}
                }
                ColumnLayout {
                    visible:root.tab===4;Layout.fillWidth:true
                    PlasmaComponents.Label {Layout.fillWidth:true;wrapMode:Text.Wrap;text:i18n("Dockmoid · Engine %1\nConnection: %2\nPlatform: %3",String(backend.engineInfo.serverVersion||i18n("Unavailable")),backend.endpointHost||i18n("Unavailable"),String(backend.engineInfo.platform||backend.engineInfo.architecture||i18n("Unavailable")))}
                    PlasmaComponents.Label {Layout.fillWidth:true;text:i18n("Service links");font.bold:true}
                    Repeater {
                        model:root.record?doctor.linksFor(root.record):[]
                        delegate:Components.ActionButton {
                            required property var modelData
                            text:modelData.label;glyph:"insert-link";onClicked:root.openUrl(modelData.url)
                            HoverHandler{id:linkHover}
                            PlasmaComponents.ToolTip {visible:linkHover.hovered;text:modelData.url+"\n"+modelData.origin}
                        }
                    }
                    PlasmaComponents.Label {Layout.fillWidth:true;wrapMode:Text.Wrap;text:i18n("Link provenance is shown on hover. Metadata establishes the declared origin, not website ownership or reachability. Add or replace a link below when metadata is missing or incorrect.")}
                    Controls.TextField {id:linkName;Layout.fillWidth:true;placeholderText:i18n("Link label, e.g. Documentation")}
                    Controls.TextField {id:linkUrl;Layout.fillWidth:true;placeholderText:"https://…"}
                    Components.ActionButton {text:i18n("Save service link");glyph:"document-save";enabled:root.record&&linkName.text.trim()!==""&&doctor.validUrl(linkUrl.text);onClicked:{if(doctor.saveLink(root.record,linkName.text,linkUrl.text)){linkName.clear();linkUrl.clear()}}}
                }
                ColumnLayout {
                    Layout.fillWidth:true;visible:doctor.plans.length>0
                    PlasmaComponents.Label {text:i18n("Plan only · selected actions");font.bold:true}
                    PlasmaComponents.Label {Layout.fillWidth:true;wrapMode:Text.Wrap;text:i18n("No changes have been made by previewing. Docker has no native dry run for these commands. A plan cannot guarantee the outcome; permissions, mounts, images and service state may change. Review commands and data/downtime effects before running.")}
                    Repeater {
                        model:doctor.plans
                        delegate:Rectangle {
                            id:planRow;required property var modelData;required property int index;Layout.fillWidth:true
                            implicitHeight:planContent.implicitHeight+Kirigami.Units.largeSpacing
                            radius:Kirigami.Units.smallSpacing
                            color:planRow.modelData.selected?Qt.alpha(Kirigami.Theme.highlightColor,Style.ALPHA.tintWeak):Qt.alpha(Kirigami.Theme.textColor,Style.ALPHA.surface1)
                            border.width:1
                            border.color:planRow.modelData.selected?Qt.alpha(Kirigami.Theme.highlightColor,Style.ALPHA.borderStrong):Qt.alpha(Kirigami.Theme.textColor,Style.ALPHA.border)
                            ColumnLayout {
                                id:planContent;anchors.fill:parent;anchors.margins:Kirigami.Units.smallSpacing
                                Controls.CheckBox {text:planRow.modelData.name+" · "+planRow.modelData.action;checked:planRow.modelData.selected;enabled:!doctor.executing;onToggled:doctor.selectPlan(planRow.index,checked)}
                                Controls.TextArea {Layout.fillWidth:true;text:planRow.modelData.command;readOnly:true;selectByMouse:true;wrapMode:TextEdit.Wrap;font.family: Kirigami.Theme.fixedWidthFont.family}
                                PlasmaComponents.Label {Layout.fillWidth:true;text:planRow.modelData.expected+(planRow.modelData.downtime?"\n"+i18n("Downtime expected."):"");wrapMode:Text.Wrap}
                            }
                        }
                    }
                    Flow {
                        Layout.fillWidth:true;spacing:Kirigami.Units.smallSpacing
                        Components.ActionButton {text:i18n("Run selected…");glyph:"media-playback-start";enabled:!doctor.executing&&!doctor.scanning&&!backend.readOnly&&doctor.plans.some(function(p){return p.selected});onClicked:confirmRun.open()}
                        Components.ActionButton {text:i18n("Clear plan");glyph:"edit-clear";enabled:!doctor.executing;onClicked:doctor.plans=[]}
                    }
                }
                Components.LogViewer {Layout.fillWidth:true;Layout.preferredHeight:240;visible:doctor.output!=="";text:doctor.output;emptyText:i18n("No action output");logMode:false}
            }
        }
        }
    }
    Controls.Dialog {
        id:confirmRun;title:i18n("Run only the selected actions?");modal:true;anchors.centerIn:parent
        width:Math.min(root.width-24,560)
        standardButtons:Controls.Dialog.Ok|Controls.Dialog.Cancel
        onOpened:{standardButton(Controls.Dialog.Ok).text=i18n("Run selected actions")}
        onAccepted:doctor.executeSelected()
        contentItem:PlasmaComponents.Label {text:doctor.plans.filter(function(p){return p.selected}).map(function(p){return p.name+" · "+p.action+(p.downtime?" · "+i18n("downtime"):"")}).join("\n")+"\n\n"+i18n("Only selected commands in the reviewed plan will run. Recreated container writable layers are replaced; mounted data and volumes are retained.");wrapMode:Text.Wrap}
    }
}
