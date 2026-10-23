pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.plasma.extras as PlasmaExtras

import "../components" as Components
import "../../lib/style.js" as Style

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
    property string stateFilterLabel: ""
    function focusSearch() { searchField.forceActiveFocus(); searchField.selectAll() }
    signal createRequested()
    signal resourcesRequested()
    signal openDetail(string recordId)
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
    /* The dock is shared by every view. */
    function dockSetting(key, fallback) { const dock = settingsCache.dock || ({}); return dock[key] === undefined ? fallback : dock[key] }
    function setDock(key, value) {
        const all = parsedSettings()
        const dock = all.dock || ({})
        dock[key] = value
        all.dock = dock
        cfg.serviceSectionSettings = JSON.stringify(all)
    }
    /* Older settings may name a page that moved to the toolbar. */
    readonly property string dockPage: { const page = String(dockSetting("page", "preview")); return ["preview", "logs", "events", "compose"].indexOf(page) >= 0 ? page : "preview" }
    readonly property bool dockExpanded: dockSetting("expanded", true) === true
    function previewMode() { return String(dockSetting("previewMode", "selection")) }

    Binding {
        target: root.backend
        property: "previewMode"
        value: root.visible && root.dockExpanded ? root.previewMode() : "off"
    }

    readonly property int dockHeaderHeight: Kirigami.Units.gridUnit * 2.4
    /* Preview is a glance; the other pages need room to work in. */
    readonly property real dockDefaultHeight: root.dockPage === "preview" ? Kirigami.Units.gridUnit * 12 : root.height * 0.55
    readonly property real dockWantedHeight: Number(dockSetting("height_" + root.dockPage, root.dockDefaultHeight))

    // ------------------------------------------------------ inspector pages ---
    readonly property var dockTabs: [
        {key: "preview", label: i18n("Overview"), glyph: "eye"},
        {key: "logs", label: i18n("Logs"), glyph: "scroll-text"},
        {key: "events", label: i18n("Events"), glyph: "bell-ring"},
        {key: "compose", label: i18n("Compose"), glyph: "file-code"}
    ]
    Component { id: previewPage; Components.ServicePreview { backend: root.backend; onOpenDetail: function(id) { root.openDetail(id) } } }
    Component { id: logsPage; InspectorLogs { backend: root.backend; onOpenDetail: function(id, tab) { root.openDetail(id) } } }
    Component { id: eventsPage; InspectorEvents { backend: root.backend } }
    Component { id: composePage; InspectorCompose { backend: root.backend } }
    readonly property var dockComponent: dockPage === "logs" ? logsPage : dockPage === "events" ? eventsPage
        : dockPage === "compose" ? composePage : previewPage

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
            onOpenDetail: function(recordId) { root.openDetail(recordId) }
            onOpenOutput: function(title, content, live, recordId) { root.openOutput(title, content, live, recordId) }
        }
    }
    Component {
        id: minimalComponent
        Components.ContainerChips {
            backend: root.backend; proxy: root.proxy; dialogs: root.dialogs
            onOpenDetail: function(recordId) { root.openDetail(recordId) }
            onOpenOutput: function(title, content, live, recordId) { root.openOutput(title, content, live, recordId) }
        }
    }
    Component {
        id: tableComponent
        Components.ContainerTable {
            detailLevel: root.detailLevel; backend: root.backend; proxy: root.proxy; dialogs: root.dialogs
            onOpenDetail: function(recordId) { root.openDetail(recordId) }
            onOpenOutput: function(title, content, live, recordId) { root.openOutput(title, content, live, recordId) }
        }
    }
    Component {
        id: groupComponent
        Components.ComposeGroupView {
            backend: root.backend; dialogs: root.dialogs; searchText: root.searchText
            rowFilter: root.rowFilter; detailLevel: root.detailLevel
            onOpenDetail: function(recordId) { root.openDetail(recordId) }
            onOpenOutput: function(title, content, live, recordId) { root.openOutput(title, content, live, recordId) }
        }
    }
    Component {
        id: gridComponent
        Components.ContainerGrid {
            detailLevel: root.detailLevel; backend: root.backend; proxy: root.proxy; dialogs: root.dialogs
            onOpenDetail: function(recordId) { root.openDetail(recordId) }
            onOpenOutput: function(title, content, live, recordId) { root.openOutput(title, content, live, recordId) }
        }
    }
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
            orientation: Qt.Vertical
            handle: Item {
                implicitHeight: 7
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: 2
                    radius: 1
                    color: Controls.SplitHandle.pressed || Controls.SplitHandle.hovered ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.border)
                }
            }
            property bool wasResizing: false
            onResizingChanged: { if (resizing) wasResizing = true; else if (wasResizing) { wasResizing = false; if (root.dockExpanded) root.setDock("height_" + root.dockPage, Math.round(dockPanel.height)) } }

            // ---- top: what the selection asks for
            Rectangle {
                id: mainPanel
                objectName: "containerListPane"
                Controls.SplitView.fillWidth: true
                Controls.SplitView.fillHeight: true
                Controls.SplitView.minimumHeight: Kirigami.Units.gridUnit * 6
                color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface1)
                border.width: 1
                border.color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.borderFaint)
                radius: Kirigami.Units.smallSpacing

                Loader {
                    anchors.fill: parent
                    visible: root.backend.engineActive && root.proxy.count > 0
                    sourceComponent: root.selectedViewComponent
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

            // ---- bottom: a page host
            Rectangle {
                id: dockPanel
                objectName: "dockPanel"
                Controls.SplitView.fillWidth: true
                Controls.SplitView.minimumHeight: root.dockHeaderHeight
                Controls.SplitView.maximumHeight: root.dockExpanded ? 16777215 : root.dockHeaderHeight
                Controls.SplitView.preferredHeight: root.dockExpanded ? Math.max(root.dockHeaderHeight + Kirigami.Units.gridUnit * 4, root.dockWantedHeight) : root.dockHeaderHeight
                color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface1)
                border.width: 1
                border.color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.borderFaint)
                radius: Kirigami.Units.smallSpacing

                /* The tab strip sits on its own darker band. */
                Rectangle {
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: root.dockHeaderHeight
                    radius: Kirigami.Units.smallSpacing
                    color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface3)
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.dockHeaderHeight
                        Layout.leftMargin: Kirigami.Units.smallSpacing
                        Layout.rightMargin: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing / 2
                        Repeater {
                            model: root.dockTabs
                            delegate: Components.DockTab {
                                required property var modelData
                                glyph: modelData.glyph
                                text: modelData.label
                                iconOnly: root.width < Kirigami.Units.gridUnit * 44
                                checked: root.dockPage === modelData.key && root.dockExpanded
                                onClicked: { root.setDock("page", modelData.key); root.setDock("expanded", true) }
                            }
                        }
                        Item { Layout.fillWidth: true }
                        // ---- the list's own controls ----
                        Components.ToolbarButton {
                            id: dockFilter
                            objectName: "dockFilterButton"
                            presentation: root.width < Kirigami.Units.gridUnit * 36 ? 0 : 1
                            glyph: "view-filter"
                            label: i18n("Filter")
                            text: i18n("Filter: %1", root.stateFilterLabel)
                            menuIndicator: true
                            checkable: true
                            checked: root.activeFilterCount > 0
                            badgeText: root.activeFilterCount > 0 ? String(root.activeFilterCount) : ""
                            onClicked: root.filterMenuRequested(dockFilter)
                        }
                        Components.ToolbarButton {
                            id: dockSort
                            objectName: "dockSortButton"
                            presentation: root.width < Kirigami.Units.gridUnit * 36 ? 0 : 1
                            glyph: "view-sort-ascending"
                            label: i18n("Sort")
                            text: i18n("Sort containers")
                            menuIndicator: true
                            onClicked: root.sortMenuRequested(dockSort)
                        }
                        PlasmaExtras.SearchField {
                            id: searchField
                            objectName: "dockSearchField"
                            Layout.preferredWidth: activeFocus || text !== "" ? Kirigami.Units.gridUnit * 11 : Kirigami.Units.gridUnit * 7
                            Layout.maximumWidth: Math.max(Kirigami.Units.gridUnit * 5, root.width * 0.3)
                            placeholderText: i18n("Search…")
                            text: root.searchText
                            onTextChanged: if (text !== root.searchText) root.searchEdited(text)
                            Keys.onEscapePressed: { clear(); root.forceActiveFocus() }
                            Behavior on Layout.preferredWidth { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                        }
                        Components.ActionToolButton {
                            glyph: root.dockExpanded ? "chevron-down" : "chevron-up"
                            text: root.dockExpanded ? i18n("Hide the inspector") : i18n("Show the inspector")
                            onClicked: root.setDock("expanded", !root.dockExpanded)
                        }
                    }
                    Rectangle {
                        visible: root.dockExpanded
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.borderFaint)
                    }
                    Loader {
                        objectName: "dockLoader"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 0
                        visible: root.dockExpanded
                        active: root.dockExpanded && root.visible
                        sourceComponent: root.dockComponent
                    }
                }
            }
        }
    }
}
