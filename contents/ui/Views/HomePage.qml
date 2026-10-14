pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels

import "../components" as Components
import "../../lib/style.js" as Style

/* Three sections share the popup's current search/state filters. */
Item {
    id: root
    objectName: "homeSectionPage"
    required property var backend
    required property var proxy
    required property var dialogs
    required property int viewMode
    required property int detailLevel
    required property string searchText
    required property var rowFilter
    property int activeFilterCount: 0
    signal clearFiltersRequested()
    signal createRequested()
    signal resourcesRequested()
    signal openDetail(string recordId)
    signal openOutput(string title, string content, bool live, string recordId)

    readonly property var cfg: plasmoid.configuration
    readonly property string viewKey: viewMode === 1 ? "table" : viewMode === 2 ? "groups" : viewMode === 3 ? "grid" : "list"
    function parsedSettings() {
        try { const value = JSON.parse(String(cfg.serviceSectionSettings || "{}")); return value && typeof value === "object" ? value : ({}) }
        catch (e) { return ({}) }
    }
    function viewSettings() { const all = parsedSettings(); return all[viewKey] || ({}) }
    function expanded(section) { const value = viewSettings()[section]; return value === undefined ? true : value === true }
    function compactDensity() { return viewSettings().inactiveDensity === "compact" }
    function updateSetting(key, value) {
        const all = parsedSettings()
        const prefs = all[viewKey] || ({})
        prefs[key] = value
        all[viewKey] = prefs
        cfg.serviceSectionSettings = JSON.stringify(all)
    }
    function toggleSection(section) { updateSetting(section, !expanded(section)) }
    function toggleDensity() { updateSetting("inactiveDensity", compactDensity() ? "comfortable" : "compact") }
    function previewMode() { return viewSettings().previewMode || "off" }
    function toolEnabled(key) { return viewSettings()["tool_" + key] === true }
    function paneHeight(key, fallback) { const sizes = viewSettings().paneSizes || ({}); return Number(sizes[key]) > 0 ? Number(sizes[key]) : fallback }
    function savePanes() {
        const sizes=Object.assign({},viewSettings().paneSizes || {})
        if(root.expanded("running"))sizes.running=runningPanel.height
        if(root.expanded("inactive"))sizes.inactive=inactivePanel.height
        if(attentionPanel.visible && root.expanded("attention"))sizes.attention=attentionPanel.height
        serviceSections.contentChildren.forEach(function(item){if(String(item.objectName).indexOf("embedded_")===0 && item.visible && root.expanded(item.objectName))sizes[item.objectName]=item.height})
        updateSetting("paneSizes",sizes)
    }
    Binding {target:root.backend;property:"previewMode";value:root.visible ? root.previewMode() : "off"}
    Component {id:doctorTool;DoctorPage {backend:root.backend;dialogs:root.dialogs;onOpenDetail:function(id,tab){root.openDetail(id)};onOpenResources:root.resourcesRequested()}}
    Component {id:newTool;DeploymentPage {backend:root.backend;onCloseRequested:root.updateSetting("tool_new",false)}}
    Component {id:resourcesTool;ResourcesPage {backend:root.backend;dialogs:root.dialogs;navigator:null;onOpenDetail:function(id){root.openDetail(id)};onDeploymentRequested:root.createRequested()}}

    function categoryFilter(category) {
        const base = root.rowFilter
        return function(sourceRow) {
            const row = root.backend.containerModel.get(sourceRow)
            if (!row || !base(sourceRow)) return false
            const state = String(row.containerState || row.state || "").toLowerCase()
            const attention = root.backend.isProblem(row)
            if (category === "attention") return attention
            if (category === "running") return (state === "running" || row.isRunning === true) && !attention
            return !attention && state !== "running" && row.isRunning !== true
        }
    }
    KItemModels.KSortFilterProxyModel {
        id: runningProxy
        objectName: "runningSectionProxy"
        sourceModel: root.backend.containerModel
        filterRowCallback: root.categoryFilter("running")
        dynamicSortFilter: true
        sortRoleName: root.cfg.sortRole
        sortOrder: root.cfg.sortAscending ? Qt.AscendingOrder : Qt.DescendingOrder
    }
    KItemModels.KSortFilterProxyModel {
        id: attentionProxy
        objectName: "attentionSectionProxy"
        sourceModel: root.backend.containerModel
        filterRowCallback: root.categoryFilter("attention")
        dynamicSortFilter: true
        sortRoleName: root.cfg.sortRole
        sortOrder: root.cfg.sortAscending ? Qt.AscendingOrder : Qt.DescendingOrder
    }
    KItemModels.KSortFilterProxyModel {
        id: inactiveProxy
        objectName: "inactiveSectionProxy"
        sourceModel: root.backend.containerModel
        filterRowCallback: root.categoryFilter("inactive")
        dynamicSortFilter: true
        sortRoleName: root.cfg.sortRole
        sortOrder: root.cfg.sortAscending ? Qt.AscendingOrder : Qt.DescendingOrder
    }
    readonly property int sectionHeaderHeight: Kirigami.Units.gridUnit * 2.1
    readonly property int innerSpacing: Kirigami.Units.smallSpacing

    Component {
        id: listComponent
        Components.ContainerList {
            backend: root.backend; proxy: runningProxy; dialogs: root.dialogs; detailLevel: root.detailLevel
            onOpenDetail: function(recordId) { root.openDetail(recordId) }
            onOpenOutput: function(title, content, live, recordId) { root.openOutput(title, content, live, recordId) }
        }
    }
    Component {
        id: minimalComponent
        Components.ContainerChips {
            backend: root.backend; proxy: runningProxy; dialogs: root.dialogs
            onOpenDetail: function(recordId) { root.openDetail(recordId) }
            onOpenOutput: function(title, content, live, recordId) { root.openOutput(title, content, live, recordId) }
        }
    }
    Component {
        id: tableComponent
        Components.ContainerTable {
            detailLevel: root.detailLevel; backend: root.backend; proxy: runningProxy; dialogs: root.dialogs
            onOpenDetail: function(recordId) { root.openDetail(recordId) }
            onOpenOutput: function(title, content, live, recordId) { root.openOutput(title, content, live, recordId) }
        }
    }
    Component {
        id: groupComponent
        Components.ComposeGroupView {
            backend: root.backend; dialogs: root.dialogs; searchText: root.searchText
            rowFilter: root.categoryFilter("running"); detailLevel: root.detailLevel
            onOpenDetail: function(recordId) { root.openDetail(recordId) }
            onOpenOutput: function(title, content, live, recordId) { root.openOutput(title, content, live, recordId) }
        }
    }
    Component {
        id: gridComponent
        Components.ContainerGrid {
            detailLevel: root.detailLevel; backend: root.backend; proxy: runningProxy; dialogs: root.dialogs
            onOpenDetail: function(recordId) { root.openDetail(recordId) }
            onOpenOutput: function(title, content, live, recordId) { root.openOutput(title, content, live, recordId) }
        }
    }
    readonly property var selectedViewComponent: viewMode === 1 ? tableComponent
        : viewMode === 2 ? groupComponent : viewMode === 3 ? gridComponent
        : detailLevel === 0 ? minimalComponent : listComponent

    Controls.Menu {
        id:layoutMenu
        Controls.MenuItem {text:i18n("Preview off");checkable:true;checked:root.previewMode()==="off";onTriggered:root.updateSetting("previewMode","off")}
        Controls.MenuItem {text:i18n("Preview on hover");checkable:true;checked:root.previewMode()==="hover";onTriggered:root.updateSetting("previewMode","hover")}
        Controls.MenuItem {text:i18n("Preview on selection");checkable:true;checked:root.previewMode()==="selection";onTriggered:root.updateSetting("previewMode","selection")}
        Controls.MenuSeparator {}
        Controls.MenuItem {text:i18n("Embed Doctor");checkable:true;checked:root.toolEnabled("doctor");onTriggered:root.updateSetting("tool_doctor",!checked?false:true)}
        Controls.MenuItem {text:i18n("Embed New containers");checkable:true;checked:root.toolEnabled("new");onTriggered:root.updateSetting("tool_new",!checked?false:true)}
        Controls.MenuItem {text:i18n("Embed Resources");checkable:true;checked:root.toolEnabled("resources");onTriggered:root.updateSetting("tool_resources",!checked?false:true)}
    }
    Controls.SplitView {
        id:workspaceSplit
        property bool wasResizing:false
        onResizingChanged:{if(resizing)wasResizing=true;else if(wasResizing){wasResizing=false;root.updateSetting("previewWidth",previewPane.width);root.updateSetting("previewHeight",previewPane.height)}}
        anchors.fill:parent
        orientation:root.width>=760?Qt.Horizontal:Qt.Vertical
        handle:Rectangle {implicitWidth:6;implicitHeight:6;color:Controls.SplitHandle.pressed?Kirigami.Theme.highlightColor:Qt.alpha(Kirigami.Theme.textColor,Style.ALPHA.border)}
        Item {
            Controls.SplitView.fillWidth:true
            Controls.SplitView.fillHeight:true
            Controls.SplitView.minimumWidth:Math.min(300,root.width)
            Controls.SplitView.minimumHeight:150
    ColumnLayout {
        anchors.fill: parent
        spacing: root.innerSpacing
        RowLayout {
            Layout.fillWidth:true
            PlasmaComponents.Label {Layout.fillWidth:true;text:i18n("Services");font.bold:true}
            Components.ActionToolButton {id:layoutOptions;glyph:"configure";text:i18n("Configure main view");onClicked:layoutMenu.popup(layoutOptions,0,layoutOptions.height)}
        }
        Controls.SplitView {
            id: serviceSections
            objectName:"servicePaneSplitter"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            orientation: Qt.Vertical
            handle: Rectangle {implicitHeight:7;color:Controls.SplitHandle.pressed?Kirigami.Theme.highlightColor:Qt.alpha(Kirigami.Theme.textColor,Style.ALPHA.border)}
            property bool wasResizing:false
            onResizingChanged: {if(resizing)wasResizing=true;else if(wasResizing){wasResizing=false;root.savePanes()}}
        Rectangle {
            id: attentionPanel
            objectName:"attentionServiceSection"
            visible: root.backend.total > 0 && attentionProxy.count > 0
            Controls.SplitView.fillWidth: true
            Controls.SplitView.minimumHeight: visible ? root.sectionHeaderHeight : 0
            Controls.SplitView.maximumHeight:root.expanded("attention")?16777215:root.sectionHeaderHeight
            Controls.SplitView.preferredHeight: !visible ? 0 : root.expanded("attention")
                ? root.paneHeight("attention",Math.min(root.height * 0.36, root.sectionHeaderHeight + attentionProxy.count * Kirigami.Units.gridUnit * 3.5))
                : root.sectionHeaderHeight
            color: Qt.alpha(Kirigami.Theme.neutralTextColor, Style.ALPHA.surface2)
            radius: Kirigami.Units.smallSpacing
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                Components.SectionHeader {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.sectionHeaderHeight
                    glyph: "dialog-warning"; glyphColor: Kirigami.Theme.neutralTextColor
                    title: i18n("Needs attention · %1", attentionProxy.count)
                    expanded: root.expanded("attention")
                    onToggled: root.toggleSection("attention")
                }
                Components.AttentionServices {
                    visible: root.expanded("attention")
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 0
                    backend: root.backend; proxy: attentionProxy; dialogs: root.dialogs
                    onOpenDetail: function(recordId) { root.openDetail(recordId) }
                    onOpenOutput: function(title, content, live, recordId) { root.openOutput(title, content, live, recordId) }
                }
            }
        }

            Rectangle {
                id: runningPanel
                objectName: "runningServiceSection"
                Controls.SplitView.fillWidth: true
                Controls.SplitView.minimumHeight: root.sectionHeaderHeight
                Controls.SplitView.maximumHeight:root.expanded("running")?16777215:root.sectionHeaderHeight
            Controls.SplitView.preferredHeight: root.expanded("running") ? root.paneHeight("running",root.height / 2) : root.sectionHeaderHeight
                Controls.SplitView.fillHeight: root.expanded("running")
                color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface1); radius: Kirigami.Units.smallSpacing
                ColumnLayout {
                    anchors.fill: parent; spacing: 0
                    Components.SectionHeader {
                        Layout.fillWidth: true; Layout.preferredHeight: root.sectionHeaderHeight
                        glyph: "media-playback-start"; glyphColor: Kirigami.Theme.positiveTextColor
                        title: i18n("Running · %1", runningProxy.count)
                        expanded: root.expanded("running")
                        onToggled: root.toggleSection("running")
                    }
                    Loader {
                        visible: root.expanded("running") && root.backend.engineActive
                        Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 0
                        sourceComponent: root.selectedViewComponent
                    }
                    PlasmaComponents.Label {
                        visible: root.expanded("running") && !root.backend.engineActive
                        Layout.fillWidth: true; Layout.fillHeight: true
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        text: root.backend.refreshing ? i18n("Connecting…") : i18n("Docker is not running")
                        color: Kirigami.Theme.disabledTextColor
                    }
                }
            }
            Rectangle {
                id: inactivePanel
                objectName: "inactiveServiceSection"
                Controls.SplitView.fillWidth: true
                Controls.SplitView.minimumHeight: root.sectionHeaderHeight
                Controls.SplitView.maximumHeight:root.expanded("inactive")?16777215:root.sectionHeaderHeight
            Controls.SplitView.preferredHeight: root.expanded("inactive") ? root.paneHeight("inactive",root.height / 2) : root.sectionHeaderHeight
                Controls.SplitView.fillHeight: root.expanded("inactive")
                color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface1); radius: Kirigami.Units.smallSpacing
                ColumnLayout {
                    anchors.fill: parent; spacing: 0
                    Components.SectionHeader {
                        Layout.fillWidth: true; Layout.preferredHeight: root.sectionHeaderHeight
                        glyph: "media-playback-stop"; glyphColor: Kirigami.Theme.disabledTextColor
                        title: i18n("Inactive · %1", inactiveProxy.count)
                        expanded: root.expanded("inactive")
                        onToggled: root.toggleSection("inactive")
                        Controls.ComboBox {
                            objectName:"inactiveViewChoice"
                            model:[i18n("Cards"),i18n("List"),i18n("Icons")]
                            currentIndex:Math.max(0,["cards","list","icons"].indexOf(root.viewSettings().inactiveView || "cards"))
                            onActivated:root.updateSetting("inactiveView",["cards","list","icons"][currentIndex])
                            Accessible.name:i18n("Inactive presentation")
                        }
                        Components.ActionToolButton { glyph: root.compactDensity() ? "view-list-text" : "view-list-details"; text: root.compactDensity() ? i18n("Comfortable density") : i18n("Compact density"); onClicked: root.toggleDensity() }
                    }
                    Components.InactiveServices {
                        visible: root.expanded("inactive")
                        Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 0
                        backend: root.backend; proxy: inactiveProxy; dialogs: root.dialogs; compact: root.compactDensity(); displayMode: root.viewSettings().inactiveView || "cards"
                        onOpenDetail: function(recordId) { root.openDetail(recordId) }
                        onOpenOutput: function(title, content, live, recordId) { root.openOutput(title, content, live, recordId) }
                    }
                }
            }
            Repeater {
                model:[{key:"doctor",label:i18n("Doctor"),component:doctorTool},{key:"new",label:i18n("Images and new containers"),component:newTool},{key:"resources",label:i18n("Resources"),component:resourcesTool}]
                delegate:Rectangle {
                    id:toolPane
                    objectName:"embedded_"+modelData.key
                    required property var modelData
                    visible:root.toolEnabled(modelData.key)
                    Controls.SplitView.minimumHeight:root.sectionHeaderHeight
                    Controls.SplitView.preferredHeight:root.expanded("embedded_"+modelData.key)?root.paneHeight("embedded_"+modelData.key,360):root.sectionHeaderHeight
                    Controls.SplitView.maximumHeight:root.expanded("embedded_"+modelData.key)?16777215:root.sectionHeaderHeight
                    color:Qt.alpha(Kirigami.Theme.textColor,Style.ALPHA.surface1);border.color:Qt.alpha(Kirigami.Theme.textColor,Style.ALPHA.borderFaint);radius:Kirigami.Units.smallSpacing
                    ColumnLayout {
                        anchors.fill:parent;spacing:0
                        Components.SectionHeader {Layout.fillWidth:true;Layout.preferredHeight:root.sectionHeaderHeight;title:toolPane.modelData.label;expanded:root.expanded("embedded_"+toolPane.modelData.key);onToggled:root.toggleSection("embedded_"+toolPane.modelData.key)}
                        Loader {objectName:"embeddedLoader_"+toolPane.modelData.key;Layout.fillWidth:true;Layout.fillHeight:true;Layout.minimumHeight:0;active:toolPane.visible && root.visible && root.expanded("embedded_"+toolPane.modelData.key);visible:active;sourceComponent:toolPane.modelData.component}
                    }
                }
            }
        }
        Kirigami.PlaceholderMessage {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.backend.engineActive && (root.backend.total === 0 || (runningProxy.count + attentionProxy.count + inactiveProxy.count === 0))
            text: root.backend.total === 0 ? (root.backend.refreshing ? i18n("Loading containers…") : i18n("No containers yet")) : i18n("No containers match the active filters")
            explanation: root.backend.total === 0 ? i18n("Create a container from an image, or refresh the engine.") : i18n("Clear filters to see all containers.")
            helpfulAction: Kirigami.Action { text: root.backend.total === 0 ? i18n("New container…") : i18n("Clear filters"); icon.name: root.backend.total === 0 ? "list-add" : "edit-clear"; enabled: root.backend.total === 0 ? !root.backend.readOnly : root.activeFilterCount > 0; onTriggered: root.backend.total === 0 ? root.createRequested() : root.clearFiltersRequested() }
        }
    }
        }
        Components.ServicePreview {
            id:previewPane
            visible:root.previewMode()!=="off"
            Controls.SplitView.preferredWidth:Number(root.viewSettings().previewWidth)||270
            Controls.SplitView.minimumWidth:Math.min(180,root.width)
            Controls.SplitView.preferredHeight:Number(root.viewSettings().previewHeight)||220
            Controls.SplitView.minimumHeight:120
            backend:root.backend
            onOpenDetail:function(id){root.openDetail(id)}
        }
    }
}
