pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.plasma.extras as PlasmaExtras

import "../components" as Components
import "../../lib/style.js" as Style
import "../../lib/inspectorLayout.js" as InspectorLayout

/*
 * The main page: the container list, and under it an inspector for the
 * container selected in the list.
 *
 *   top   the containers the filters ask for
 *   dock  Overview, Logs, Events and Compose for the selection, plus the
 *         list's Filter, Sort and Search, which sit next to what they change
 */
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
    /* The list's controls live in the dock bar; PopupView owns their menus. */
    signal filterMenuRequested(Item anchor)
    signal sortMenuRequested(Item anchor)
    signal searchEdited(string text)
    /* Go to, and Docker Hub search, from the bottom strip's search. */
    signal pageRequested(string key)
    signal imageSearchRequested(string query)
    function openSearch() { search.open() }
    /* A bottom tab: the open one hides the pane, any other opens its page. */
    function tabPressed(key) { root.saveDock(InspectorLayout.pressTab(root.storedDock(), key)) }
    property string stateFilterLabel: ""
    property string stateFilterKey: "all"
    property string stateFilterIcon: ""
    property bool problemsOnly: false
    /* "search", "state" or "problems": one active filter's × was pressed. */
    signal removeFilter(string which)
    /* Selection mode: review `action` for the picked containers before it runs. */
    signal batchReviewRequested(string action)
    /* The active filters as removable chips over the list. */
    readonly property var filterChips: {
        const chips = []
        if (root.problemsOnly) chips.push({key: "problems", glyph: "circle-alert", text: i18n("Needs Attention")})
        if (root.stateFilterKey !== "all") chips.push({key: "state", glyph: root.stateFilterIcon, text: root.stateFilterLabel})
        if (root.searchText.trim() !== "") chips.push({key: "search", glyph: "search", text: "“" + root.searchText.trim() + "”"})
        return chips
    }
    signal createRequested()
    signal resourcesRequested()
    signal openDetail(string recordId, int tab)
    signal openOutput(string title, string content, bool live, string recordId)

    readonly property var cfg: plasmoid.configuration

    // ------------------------------------------------------- stored layout ---
    function parsedSettings() {
        try { const value = JSON.parse(String(cfg.serviceSectionSettings || "{}")); return value && typeof value === "object" ? value : ({}) }
        catch (e) { return ({}) }
    }
    /* Parsed once per change of the stored string, not on every binding read. */
    readonly property var settingsCache: { const stored = cfg.serviceSectionSettings; return parsedSettings() }
    /* Per-view settings, kept for the view components and the test harness. */
    readonly property string viewKey: viewMode === 1 ? "table" : viewMode === 2 ? "groups" : viewMode === 3 ? "grid" : "list"
    function viewSettings() { return settingsCache[viewKey] || ({}) }
    function updateSetting(key, value) {
        const all = parsedSettings()
        const prefs = all[viewKey] || ({})
        prefs[key] = value
        all[viewKey] = prefs
        cfg.serviceSectionSettings = JSON.stringify(all)
    }
    /* The dock (the inspector's settings) is shared by every view; its rules live
       in inspectorLayout.js, and saveDock is the one place that stores it. */
    function dockSetting(key, fallback) { const dock = settingsCache.dock || ({}); return dock[key] === undefined ? fallback : dock[key] }
    function storedDock() { return parsedSettings().dock || ({}) }
    function saveDock(dock) {
        const all = parsedSettings()
        all.dock = dock
        cfg.serviceSectionSettings = JSON.stringify(all)
    }
    function setDock(key, value) {
        const dock = root.storedDock()
        dock[key] = value
        root.saveDock(dock)
    }
    readonly property int dockHeaderHeight: Kirigami.Units.gridUnit * 2.4
    /* Page, shown, side by side and the panes' sizes, from the stored dock and the popup's size. */
    readonly property var layout: InspectorLayout.layout(root.settingsCache.dock, {width: root.width, height: root.height, gridUnit: Kirigami.Units.gridUnit, headerHeight: root.dockHeaderHeight})
    readonly property string dockPage: root.layout.page
    readonly property bool dockExpanded: root.layout.shown
    function previewMode() { return String(dockSetting("previewMode", "selection")) }

    Binding {
        target: root.backend
        property: "previewMode"
        value: root.visible && root.dockExpanded ? root.previewMode() : "off"
    }


    // ------------------------------------------------------ inspector pages ---
    readonly property var dockTabs: [
        {key: "preview", label: i18n("Overview"), glyph: "eye"},
        {key: "logs", label: i18n("Logs"), glyph: "scroll-text"},
        {key: "events", label: i18n("Events"), glyph: "bell-ring"},
        {key: "compose", label: i18n("Compose"), glyph: "file-code"},
        {key: "health", label: i18n("Health"), glyph: "heart-pulse"}
    ]
    Component { id: previewPage; Components.ServicePreview { backend: root.backend; onOpenDetail: function(id) { root.openDetail(id, 0) } } }
    Component { id: logsPage; InspectorLogs { backend: root.backend; onOpenDetail: function(id, tab) { root.openDetail(id, tab) } } }
    Component { id: eventsPage; InspectorEvents { backend: root.backend } }
    Component { id: composePage; InspectorCompose { backend: root.backend } }
    readonly property var dockComponent: dockPage === "logs" ? logsPage : dockPage === "events" ? eventsPage
        : dockPage === "compose" ? composePage : dockPage === "health" ? healthPage : previewPage
    Component { id: healthPage; InspectorHealth { backend: root.backend; onOpenDetail: function(id, tab) { root.openDetail(id, tab) } } }

    // ------------------------------------------------ selection continuity ---
    /*
     * The inspected container (backend.previewRecordId) is the one selection
     * every view shares. Switching view scrolls the new one to it, and when the
     * list's filters hide it the inspector says so instead of silently showing
     * a container the list no longer has.
     */
    function proxyRowOf(id) {
        const model = root.backend.containerModel
        if (!id || !model) return -1
        for (let i = 0; i < model.count; i++)
            if (model.get(i).containerKey === id) return root.proxy.mapFromSource(model.index(i, 0)).row
        return -1
    }
    readonly property var selectedRecord: { const revision = root.backend.revision; return root.backend.findRecord(root.backend.previewRecordId) }
    readonly property bool selectionHidden: {
        const rows = root.proxy.count, filter = root.rowFilter
        return !!root.selectedRecord && root.proxyRowOf(root.backend.previewRecordId) < 0
    }
    /* The loaded view: reveal(row), or revealId(id) for Groups. A var, since the views share no base type. */
    readonly property var loadedView: viewLoader.item
    function revealSelection() {
        if (!root.loadedView) return
        if (typeof root.loadedView.revealId === "function") root.loadedView.revealId(root.backend.previewRecordId)
        else if (typeof root.loadedView.reveal === "function") root.loadedView.reveal(root.proxyRowOf(root.backend.previewRecordId))
    }

    // ---------------------------------------------------- the container list ---
    Component {
        id: listComponent
        Components.ContainerList {
            backend: root.backend; proxy: root.proxy; dialogs: root.dialogs; detailLevel: root.detailLevel
            collapsedGroups: root.settingsCache.list && root.settingsCache.list.collapsed ? root.settingsCache.list.collapsed : ({})
            onGroupToggled: function(group) {
                const next = Object.assign({}, collapsedGroups)
                if (next[group]) delete next[group]; else next[group] = true
                root.updateSetting("collapsed", next)
            }
            onOpenDetail: function(recordId) { root.openDetail(recordId, 0) }
            onOpenOutput: function(title, content, live, recordId) { root.openOutput(title, content, live, recordId) }
        }
    }
    Component {
        id: minimalComponent
        Components.ContainerChips {
            backend: root.backend; proxy: root.proxy; dialogs: root.dialogs
            onOpenDetail: function(recordId) { root.openDetail(recordId, 0) }
            onOpenOutput: function(title, content, live, recordId) { root.openOutput(title, content, live, recordId) }
        }
    }
    Component {
        id: tableComponent
        Components.ContainerTable {
            detailLevel: root.detailLevel; backend: root.backend; proxy: root.proxy; dialogs: root.dialogs
            onOpenDetail: function(recordId) { root.openDetail(recordId, 0) }
            onOpenOutput: function(title, content, live, recordId) { root.openOutput(title, content, live, recordId) }
        }
    }
    Component {
        id: groupComponent
        Components.ComposeGroupView {
            backend: root.backend; dialogs: root.dialogs; searchText: root.searchText
            rowFilter: root.rowFilter; detailLevel: root.detailLevel
            onOpenDetail: function(recordId) { root.openDetail(recordId, 0) }
            onOpenOutput: function(title, content, live, recordId) { root.openOutput(title, content, live, recordId) }
        }
    }
    Component {
        id: gridComponent
        Components.ContainerGrid {
            detailLevel: root.detailLevel; backend: root.backend; proxy: root.proxy; dialogs: root.dialogs
            onOpenDetail: function(recordId) { root.openDetail(recordId, 0) }
            onOpenOutput: function(title, content, live, recordId) { root.openOutput(title, content, live, recordId) }
        }
    }
    /* The inspector sits below the list, or to its right when the strip's
       layout button says so; a popup too narrow for two panes stacks them. */
    readonly property bool roomForSide: root.layout.roomForSide
    readonly property bool sidePreferred: root.layout.sidePreferred
    readonly property bool sideBySide: root.layout.sideBySide
    readonly property var selectedViewComponent: viewMode === 1 ? tableComponent
        : viewMode === 2 ? groupComponent : viewMode === 3 ? gridComponent
        : detailLevel === 0 ? minimalComponent : listComponent

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing



        Controls.SplitView {
            id: panes
            objectName: "servicePaneSplitter"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            orientation: root.layout.orientation === "horizontal" ? Qt.Horizontal : Qt.Vertical
            // Draggable either way: a bar across when stacked, upright when side by side.
            handle: Item {
                implicitHeight: 7
                implicitWidth: 7
                Rectangle {
                    anchors.centerIn: parent
                    width: panes.orientation === Qt.Horizontal ? 2 : parent.width
                    height: panes.orientation === Qt.Horizontal ? parent.height : 2
                    radius: 1
                    color: Controls.SplitHandle.pressed || Controls.SplitHandle.hovered ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.border)
                }
            }
            property bool wasResizing: false
            onResizingChanged: {
                if (resizing) { wasResizing = true; return }
                if (!wasResizing) return
                wasResizing = false
                const dock = root.storedDock()
                const next = InspectorLayout.resized(dock, root.layout, dockPanel.width, dockPanel.height)
                if (next !== dock) root.saveDock(next)
            }

            // ---- top: what the selection asks for
            Rectangle {
                id: mainPanel
                objectName: "containerListPane"
                Controls.SplitView.fillWidth: true
                Controls.SplitView.fillHeight: true
                Controls.SplitView.minimumHeight: root.layout.listMinH
                Controls.SplitView.minimumWidth: root.layout.listMinW
                color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface1)
                border.width: 1
                border.color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.borderFaint)
                radius: Kirigami.Units.smallSpacing

                // Active filters, each removable on its own, so it is plain what the
                // list leaves out and which control did it.
                Flow {
                    id: chipRow
                    objectName: "filterChips"
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Kirigami.Units.smallSpacing }
                    visible: root.filterChips.length > 0
                    height: visible ? implicitHeight : 0
                    spacing: Kirigami.Units.smallSpacing
                    Repeater {
                        model: root.filterChips
                        delegate: Rectangle {
                            id: chip
                            required property var modelData
                            implicitWidth: chipLine.implicitWidth + Kirigami.Units.smallSpacing * 2
                            implicitHeight: Kirigami.Units.gridUnit * 1.3
                            radius: height / 2
                            color: Qt.alpha(Kirigami.Theme.highlightColor, Style.ALPHA.tintFaint)
                            border.color: Qt.alpha(Kirigami.Theme.highlightColor, Style.WASH_BORDER.hover)
                            Row {
                                id: chipLine
                                anchors.centerIn: parent
                                spacing: Kirigami.Units.smallSpacing / 2
                                Components.ActionIcon { anchors.verticalCenter: parent.verticalCenter; glyph: chip.modelData.glyph; implicitWidth: Kirigami.Units.iconSizes.small * 0.8; implicitHeight: implicitWidth }
                                PlasmaComponents.Label { anchors.verticalCenter: parent.verticalCenter; text: chip.modelData.text; font: Kirigami.Theme.smallFont; elide: Text.ElideRight; width: Math.min(implicitWidth, Kirigami.Units.gridUnit * 10) }
                                Components.IconButton {
                                    anchors.verticalCenter: parent.verticalCenter
                                    glyph: "x"
                                    glyphSize: Kirigami.Units.iconSizes.small * 0.7
                                    implicitWidth: Kirigami.Units.gridUnit
                                    text: i18n("Remove this filter")
                                    onClicked: root.removeFilter(chip.modelData.key)
                                }
                            }
                        }
                    }
                }
                // Selection mode's bar: how many are picked (and hidden by filters),
                // the actions to review for them, and the way out.
                Rectangle {
                    id: selectionBar
                    objectName: "selectionBar"
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 1 }
                    visible: root.backend.selection.active
                    height: visible ? selectionLine.implicitHeight + Kirigami.Units.smallSpacing * 2 : 0
                    color: Qt.alpha(Kirigami.Theme.highlightColor, Style.ALPHA.tintFaint)
                    readonly property int hidden: { const rows = root.proxy.count, filter = root.rowFilter; return root.backend.selection.hiddenCount(function (id) { return root.proxyRowOf(id) >= 0 }) }
                    Flow {
                        id: selectionLine
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Kirigami.Units.smallSpacing }
                        spacing: Kirigami.Units.smallSpacing
                        PlasmaComponents.Label {
                            height: Kirigami.Units.gridUnit * 1.7
                            verticalAlignment: Text.AlignVCenter
                            text: selectionBar.hidden > 0 ? i18n("%1 selected · %2 hidden by filters", root.backend.selection.pickedIds.length, selectionBar.hidden)
                                : i18np("%1 selected", "%1 selected", root.backend.selection.pickedIds.length)
                        }
                        Repeater {
                            model: [["start", "media-playback-start", i18n("Start")], ["stop", "media-playback-stop", i18n("Stop")],
                                    ["restart", "view-refresh", i18n("Restart")], ["update", "cloud-download", i18n("Update…")]]
                            delegate: Components.DockButton {
                                required property var modelData
                                glyph: modelData[1]; text: modelData[2]
                                iconOnly: root.width < Kirigami.Units.gridUnit * 30
                                visible: !root.backend.readOnly
                                enabled: root.backend.selection.pickedIds.length > 0 && !root.backend.selection.running
                                onClicked: root.batchReviewRequested(modelData[0])
                            }
                        }
                        Components.DockButton { glyph: "x"; text: i18n("Clear"); iconOnly: true; enabled: root.backend.selection.pickedIds.length > 0; onClicked: root.backend.selection.clear() }
                        Components.DockButton { glyph: "check"; text: i18n("Done"); onClicked: root.backend.selection.active = false }
                    }
                }
                Loader {
                    id: viewLoader
                    anchors { left: parent.left; right: parent.right; bottom: selectionBar.visible ? selectionBar.top : parent.bottom; top: chipRow.visible ? chipRow.bottom : parent.top }
                    anchors.topMargin: chipRow.visible ? Kirigami.Units.smallSpacing : 0
                    visible: root.backend.engineActive && root.proxy.count > 0
                    // Dimmed while the last refresh failed: these are last known states.
                    opacity: root.backend.dataStale && root.backend.lastUpdatedMs > 0 ? 0.7 : 1
                    sourceComponent: root.selectedViewComponent
                    // After the first layout pass: a fresh view has no height or delegates yet.
                    onLoaded: revealTimer.restart()
                    Timer { id: revealTimer; interval: 0; onTriggered: root.revealSelection() }
                }
                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    visible: !root.backend.engineActive
                    text: root.backend.refreshing ? i18n("Connecting…") : i18n("%1 is not running", root.backend.engineName)
                    color: Kirigami.Theme.disabledTextColor
                }
                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.gridUnit * 2
                    visible: root.backend.engineActive && root.proxy.count === 0
                    text: root.backend.total === 0 ? (root.backend.refreshing ? i18n("Loading containers…") : i18n("No containers yet")) : i18n("No containers match the active filters")
                    explanation: root.backend.total === 0 ? i18n("Create a container from an image, or refresh the engine.") : i18n("Clear filters to see all containers.")
                    helpfulAction: Kirigami.Action {
                        text: root.backend.total === 0 ? i18n("Deploy a Container…") : i18n("Clear filters")
                        icon.name: root.backend.total === 0 ? "list-add" : "edit-clear"
                        enabled: root.backend.total === 0 ? !root.backend.readOnly : root.activeFilterCount > 0
                        onTriggered: root.backend.total === 0 ? root.createRequested() : root.clearFiltersRequested()
                    }
                }
            }

            // ---- the inspector: below the list, or to its right side by side; its tabs at its foot
            Rectangle {
                id: dockPanel
                objectName: "dockPanel"
                // Below the list (vertical) or to its right (side by side, only while
                // shown). Collapsed, only the strip shows, below the list. The list
                // fills what is left, so dragging the divider sizes this pane.
                Controls.SplitView.minimumHeight: root.layout.pane.minH
                Controls.SplitView.maximumHeight: root.layout.pane.maxH
                Controls.SplitView.preferredHeight: root.layout.pane.prefH
                Controls.SplitView.minimumWidth: root.layout.pane.minW
                Controls.SplitView.preferredWidth: root.layout.pane.prefW
                color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface1)
                border.width: 1
                border.color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.borderFaint)
                radius: Kirigami.Units.smallSpacing

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0
                    Kirigami.InlineMessage {
                        objectName: "selectionHiddenMessage"
                        Layout.fillWidth: true
                        Layout.margins: Kirigami.Units.smallSpacing
                        visible: root.dockExpanded && root.selectionHidden
                        type: Kirigami.MessageType.Information
                        text: i18n("%1 is hidden by the list's filters.", root.selectedRecord ? root.selectedRecord.name : "")
                        actions: [
                            Kirigami.Action {
                                text: i18n("Show in List")
                                icon.name: "edit-clear"
                                onTriggered: { root.clearFiltersRequested(); Qt.callLater(root.revealSelection) }
                            }
                        ]
                    }
                    Loader {
                        objectName: "dockLoader"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 0
                        active: root.dockExpanded && root.visible
                        sourceComponent: root.dockComponent
                    }
                    /*
                     * The inspector's tabs, pinned to the bottom whatever the pane's height.
                     * A tab opens its page above; pressing the open tab again hides the pane.
                     */
                    Rectangle {
                        id: dockStrip
                        objectName: "dockStrip"
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.dockHeaderHeight
                        radius: Kirigami.Units.smallSpacing
                        color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface3)
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Kirigami.Units.smallSpacing
                            anchors.rightMargin: Kirigami.Units.smallSpacing
                            spacing: Kirigami.Units.smallSpacing / 2
                            RowLayout {
                            id: stripTabs
                            spacing: Kirigami.Units.smallSpacing / 2
                            // Select: ticks on every container, for acting on several at once.
                            Components.DockButton {
                                objectName: "selectButton"
                                glyph: "square-check"
                                iconOnly: dockStrip.width < Kirigami.Units.gridUnit * 36
                                text: root.backend.selection.pickedIds.length > 0 ? i18n("Select (%1)", root.backend.selection.pickedIds.length) : i18n("Select")
                                variant: root.backend.selection.active ? "primary" : "flat"
                                onClicked: root.backend.selection.active = !root.backend.selection.active
                            }
                            Repeater {
                                model: root.dockTabs
                                delegate: Components.DockTab {
                                    required property var modelData
                                    objectName: "dockTab"
                                    glyph: modelData.glyph
                                    text: modelData.label
                                    // Narrow: only the open tab keeps its label.
                                    iconOnly: dockStrip.width < Kirigami.Units.gridUnit * 40 && !checked
                                    checked: root.dockPage === modelData.key && root.dockExpanded
                                    onClicked: root.tabPressed(modelData.key)
                                }
                            }
                            }
                            Item { Layout.fillWidth: true }
                            // Search, pinned right; its look is set in Settings → Appearance.
                            Components.SearchControl {
                                id: search
                                objectName: "dockSearch"
                                backend: root.backend
                                containerText: root.searchText
                                // What the tabs and the buttons after it leave, so an open field never pushes them off the strip.
                                available: dockStrip.width - Kirigami.Units.smallSpacing * 4 - stripTabs.implicitWidth
                                    - (sideButton.visible ? sideButton.implicitWidth : 0) - foldButton.implicitWidth
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                onContainerTextEdited: function (text) { root.searchEdited(text) }
                                onPageRequested: function (key) { root.pageRequested(key) }
                                onContainerRequested: function (recordId) { root.openDetail(recordId, 0) }
                                onImageSearchRequested: function (query) { root.imageSearchRequested(query) }
                            }
                            // Below the list, or to its right; drag the divider to resize either way.
                            Components.ActionToolButton {
                                id: sideButton
                                objectName: "dockSideButton"
                                visible: root.roomForSide
                                glyph: root.sidePreferred ? "layout-panel-top" : "layout-panel-left"
                                text: root.sidePreferred ? i18n("Put the inspector below the list") : i18n("Put the inspector beside the list")
                                onClicked: root.saveDock(InspectorLayout.toggleSide(root.storedDock(), root.roomForSide))
                            }
                            Components.ActionToolButton {
                                id: foldButton
                                glyph: root.sidePreferred ? (root.dockExpanded ? "chevron-right" : "chevron-left")
                                    : (root.dockExpanded ? "chevron-down" : "chevron-up")
                                text: root.dockExpanded ? i18n("Hide the inspector") : i18n("Show the inspector")
                                onClicked: root.saveDock(InspectorLayout.toggleShown(root.storedDock()))
                            }
                        }
                    }
                }
            }
        }
    }
}
