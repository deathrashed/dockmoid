import QtQuick
import "../../lib/deployment.js" as Deploy
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

import "../components" as Components
import "../../lib/profiles.js" as Profiles
import "../../lib/actionIcons.js" as ActionIcons
import "../../lib/style.js" as Style

/*
 * PopupView — the whole expanded UI, in a form that works unchanged both
 * inside the applet popup and inside the detached window.
 *
 * Layout:
 *   header      one responsive toolbar row
 *   activity    thin bar showing time until the next poll
 *   error       inline message for the last failed command
 *   stack       home (list/table/compose) -> detail -> output
 *   status bar  running/stopped totals, CPU and memory
 *
 * It owns the view state (which view, how much detail, what search text) and
 * hands plain values down, so none of the pages below it need a back channel.
 */
PlasmaExtras.Representation {
    id: root

    required property var backend
    required property var applet

    readonly property var cfg: plasmoid.configuration

    property int viewMode: cfg.defaultViewMode
    property int listDetail: cfg.defaultDetailLevel
    property int tableDetail: cfg.defaultTableDetailLevel
    property int gridDetail: cfg.defaultGridDetailLevel
    readonly property int detailLevel: viewMode === 1 ? tableDetail : viewMode === 3 ? gridDetail : listDetail
    readonly property var detailNames: [i18n("Minimal"), i18n("Normal"), i18n("Detailed"), i18n("Verbose")]
    property string searchText: ""
    /* View, Detail, Filter, Sort and Search only act on the container list. */
    readonly property bool onHome: stack.depth <= 1
    /* Show only what needs attention: unhealthy, restarting, crashed or paused. */
    property bool problemsOnly: false
    readonly property int activeFilterCount: Number(stateFilter !== "all") + Number(problemsOnly) + Number(searchText.trim() !== "")
    function clearFilters() { searchText = ""; stateFilter = "all"; problemsOnly = false }
    property string stateFilter: "all"
    readonly property var stateChoices: [
        {key:"all",label:i18n("All containers")},{key:"running",label:i18n("Running")},
        {key:"not-created",label:i18n("Not created")},{key:"stopped",label:i18n("Stopped")},{key:"paused",label:i18n("Paused")},
        {key:"restarting",label:i18n("Restarting")},{key:"created",label:i18n("Not started")},
        {key:"unhealthy",label:i18n("Unhealthy")},{key:"failed",label:i18n("Failed")}
    ]
    readonly property string stateFilterLabel: (stateChoices.find(function(s){return s.key===root.stateFilter}) || stateChoices[0]).label

    readonly property int toolbarStyle: Math.max(0, Math.min(3, Number(cfg.toolbarStyle) || 0))
    // Size the visible set from the button captions and current presentation.
    // Hidden controls remain available in More, with zero menu-row height.
    readonly property var toolbarSlots: {
        const widths = {view:viewButton.idealWidth, detail:detailButton.idealWidth,
            filter:filterButton.idealWidth + (root.activeFilterCount > 0 ? clearFilterButton.implicitWidth + Kirigami.Units.smallSpacing / 2 : 0), sort:sortButton.idealWidth, search:searchButton.idealWidth,
            new:newButton.idealWidth, resources:resourcesButton.idealWidth,
            doctor:doctorButton.idealWidth, maintain:maintainButton.idealWidth,
            refresh:refreshButton.idealWidth, detach:detachButton.idealWidth, more:toolsButton.idealWidth}
        const groups = [["view","detail"],["filter","sort","search"],
            ["new","resources","doctor","maintain"],["refresh","detach","more"]]
        const gap = Kirigami.Units.smallSpacing / 2
        function requiredWidth(keys) {
            let total = Kirigami.Units.smallSpacing * 2
            const counts = groups.map(function(group) {
                const members = group.filter(function(key) { return keys.indexOf(key) >= 0 })
                members.forEach(function(key) { total += widths[key] })
                total += Math.max(0, members.length - 1) * gap
                return members.length
            })
            if (counts[0] && counts[1]) total += Kirigami.Units.smallSpacing * 2 + 1 + gap * 2
            if (counts[2] && counts[3]) total += Kirigami.Units.smallSpacing * 2 + 1 + gap * 2
            if (stack.depth > 1) total += backButton.implicitWidth + Kirigami.Units.smallSpacing
            return total
        }
        let keep = ["view","more"]
        ;["filter","sort","search","doctor","detach","refresh","new","detail","resources","maintain"].forEach(function(key) {
            const next = keep.concat([key])
            if (requiredWidth(next) <= headerRow.width) keep = next
        })
        return keep
    }
    readonly property bool directDetail: toolbarSlots.indexOf("detail") >= 0
    readonly property bool directFilter: toolbarSlots.indexOf("filter") >= 0
    readonly property bool directSort: toolbarSlots.indexOf("sort") >= 0
    readonly property bool directSearch: toolbarSlots.indexOf("search") >= 0
    readonly property bool directRefresh: toolbarSlots.indexOf("refresh") >= 0
    readonly property bool directNew: toolbarSlots.indexOf("new") >= 0
    readonly property bool directResources: toolbarSlots.indexOf("resources") >= 0
    readonly property bool directDoctor: toolbarSlots.indexOf("doctor") >= 0
    readonly property bool directMaintain: toolbarSlots.indexOf("maintain") >= 0
    readonly property bool directDetach: toolbarSlots.indexOf("detach") >= 0
    readonly property var viewChoices: [
        {mode:0, icon:"view-list-text", label:i18n("List")},
        {mode:1, icon:"view-list-details", label:i18n("Table")},
        {mode:3, icon:"view-grid", label:i18n("Grid")},
        {mode:2, icon:"view-list-tree", label:i18n("Groups")}
    ]
    readonly property var sortChoices: [
        {role:"sortKey", label:i18n("Pinned, then running")},
        {role:"name", label:i18n("Name")}, {role:"cpuPct", label:i18n("CPU")},
        {role:"memPct", label:i18n("Memory")}, {role:"project", label:i18n("Project")}
    ]
    onSearchTextChanged: if (searchPopupField.text !== searchText) searchPopupField.text = searchText

    implicitWidth: Kirigami.Units.gridUnit * 36
    implicitHeight: Kirigami.Units.gridUnit * 24

    // ====================================================== filtering ====

    /*
     * One proxy feeds the list, the table and the compose groups, so the
     * search box and the column sort can never disagree with each other.
     * Filtering happens on a pre-joined searchKey (name + image + project +
     * ports + id) so "qbittorrent" finds a container however it is named.
     *
     * The proxy is the single owner of the sort order: the config seeds it,
     * and clicking a table header mutates it in place.
     */
    /*
     * Search is a plain substring test on the pre-joined searchKey, so typing
     * "(" or "[" can never be an invalid pattern. The callback is rebuilt
     * whenever its inputs change; assigning a new function is what makes the
     * proxy re-run the filter.
     */
    readonly property var rowFilter: {
        var needle = root.searchText.toLowerCase()
        var problems = root.problemsOnly
        var state = root.stateFilter
        var source = root.backend.containerModel
        return function (sourceRow) {
            var row = source.get(sourceRow)
            if (!row) return false
            if (problems && !root.backend.isProblem(row)) return false
            if (state === "failed" ? !root.backend.isProblem(row) || (row.containerState || row.state) !== "exited" && (row.containerState || row.state) !== "dead" : !Deploy.matchesState(row,state)) return false
            return needle === "" || row.searchKey.indexOf(needle) !== -1
        }
    }

    KItemModels.KSortFilterProxyModel {
        id: proxy
        sourceModel: root.backend.containerModel
        filterCaseSensitivity: Qt.CaseInsensitive
        sortCaseSensitivity: Qt.CaseInsensitive
        recursiveFilteringEnabled: true
        filterRowCallback: root.rowFilter
        dynamicSortFilter: true
        sortRoleName: root.cfg.sortRole
        sortOrder: root.cfg.sortAscending ? Qt.AscendingOrder : Qt.DescendingOrder
    }

    // ======================================================== actions ====

    function refreshNow() {
        root.backend.refresh({
            "force": true,
            "withStats": true,
            "withDisk": root.cfg.showDiskUsage
        })
    }

    function showResources() {
        var page = stack.push(Qt.resolvedUrl("ResourcesPage.qml"), {
            "backend": root.backend,
            "dialogs": dialogs,
            "navigator": stack
        })
        if (page) {
            page.openDetail.connect(function(id) { root.showDetail(id) })
            page.deploymentRequested.connect(function(tab) { root.showDeployment(tab) })
        }
    }

    function selectView(mode) {
        root.viewMode = mode
        if (stack.depth > 1) stack.pop(stack.get(0))
    }
    function selectDetail(level) {
        if ([0, 1, 2, 3].indexOf(level) < 0) return
        if (root.viewMode === 1) root.tableDetail = level
        else if (root.viewMode === 3) root.gridDetail = level
        else root.listDetail = level
        if (stack.depth > 1) stack.pop(stack.get(0))
    }
    function selectSort(role) {
        if (root.cfg.sortRole !== role) root.cfg.sortAscending = role !== "cpuPct" && role !== "memPct"
        root.cfg.sortRole = role
    }
    function openSearch() {
        toolsMenu.close()
        if (searchPopup.opened) searchPopup.close()
        else searchPopup.open()
    }
    function showDeployment(initialTab) {
        const page = stack.push(Qt.resolvedUrl("DeploymentPage.qml"), {backend:root.backend,initialTab:initialTab || 0})
        if (page) page.closeRequested.connect(function() { stack.pop() })
    }
    function showDoctor(tab,cleanup) {
        if (stack.currentItem && stack.currentItem.objectName === "doctorPage") {
            stack.currentItem.tab=tab || 0
            if (cleanup) root.backend.doctor.cleanupPlan(cleanup)
            return
        }
        const page=stack.push(Qt.resolvedUrl("DoctorPage.qml"),{backend:root.backend,dialogs:dialogs,tab:tab || 0,initialCleanup:cleanup || ""})
        if (page) {
            page.openDetail.connect(function(id,initialTab){root.showDetail(id,initialTab)})
            page.openResources.connect(function(){root.showResources()})
            const index=root.backend.records.findIndex(function(r){return root.backend.isProblem(r)})
            if (tab===1 && index>=0) page.selectedIndex=index
        }
    }
    function showActivity() {
        const page = stack.push(Qt.resolvedUrl("ActivityPage.qml"), {backend: root.backend})
        if (page) page.openDetail.connect(function(id) { root.showDetail(id) })
    }
    function checkUpdates() {
        root.backend.updateState["__checked"] = 0
        root.backend.startUpdateCheck(true)
    }

    QQC2.Popup {
        id: searchPopup
        objectName: "containerSearchPopup"
        parent: root
        x: Math.max(Kirigami.Units.smallSpacing, Math.min((root.directSearch ? searchButton : toolsButton).mapToItem(root, 0, 0).x, root.width - width - Kirigami.Units.smallSpacing))
        y: (root.directSearch ? searchButton : toolsButton).mapToItem(root, 0, 0).y + toolsButton.height + Kirigami.Units.smallSpacing
        width: Math.min(root.width - Kirigami.Units.smallSpacing * 2, Kirigami.Units.gridUnit * 24)
        focus: true
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
        onOpened: { searchPopupField.forceActiveFocus(); searchPopupField.selectAll() }
        contentItem: ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            PlasmaExtras.SearchField {
                id: searchPopupField
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                placeholderText: i18n("Search containers")
                onTextChanged: if (root.searchText !== text) root.searchText = text
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: i18n("Search by name, image, project, port or ID. Ctrl+F opens this search.")
                color: Kirigami.Theme.disabledTextColor
                font: Kirigami.Theme.smallFont
            }
            Components.ActionButton { text: i18n("Clear search"); glyph: "edit-clear"; enabled: root.searchText !== ""; onClicked: root.searchText = "" }
        }
    }

    PlasmaComponents.Menu {
        id: stateMenu
        delegate: Components.ActionMenuDelegate { width: parent ? parent.width : implicitWidth }
        Instantiator {
            model: root.stateChoices
            delegate: Components.ActionMenuDelegate {
                required property var modelData
                text: modelData.label
                icon.name: ""
                icon.source: Qt.resolvedUrl(ActionIcons.path(modelData.key === "all" ? "view-list-text" : modelData.key === "paused" ? "media-playback-pause" : modelData.key === "running" ? "media-playback-start" : modelData.key === "unhealthy" ? "dialog-warning" : "media-playback-stop"))
                checkable: true
                checked: root.stateFilter === modelData.key
                onTriggered: root.stateFilter = modelData.key
            }
            onObjectAdded: function(i,o) { stateMenu.insertItem(i,o) }
            onObjectRemoved: function(i,o) { stateMenu.removeItem(o) }
        }
    }
    PlasmaComponents.Menu {
        id: maintainMenu
        objectName: "maintenanceMenu"
        delegate: Components.ActionMenuDelegate {width:parent?parent.width:implicitWidth}
        Components.ActionMenuDelegate {text:i18n("Updates");enabled:false}
        Components.ActionMenuDelegate {text:i18n("Check for updates");icon.source:Qt.resolvedUrl(ActionIcons.path("package-search"));enabled:root.backend.engineActive&&root.backend.buildxAvailable&&!root.backend.updateRunning;onTriggered:root.checkUpdates()}
        Components.ActionMenuDelegate {text:i18n("Review updates…");icon.source:Qt.resolvedUrl(ActionIcons.path("package-check"));enabled:root.backend.engineActive&&!root.backend.batchUpdating;onTriggered:reviewUpdates.open()}
        Components.ActionMenuDelegate {text:i18n("Pull images…");icon.source:Qt.resolvedUrl(ActionIcons.path("system-download"));enabled:root.backend.engineActive&&!root.backend.readOnly;onTriggered:root.showDoctor(1)}
        PlasmaComponents.MenuSeparator {}
        Components.ActionMenuDelegate {text:i18n("Diagnostics");enabled:false}
        Components.ActionMenuDelegate {text:i18n("Check engine connection");icon.source:Qt.resolvedUrl(ActionIcons.path("view-refresh"));onTriggered:{root.refreshNow();root.showDoctor(0)}}
        Components.ActionMenuDelegate {text:i18n("Inspect unhealthy services");icon.source:Qt.resolvedUrl(ActionIcons.path("dialog-warning"));onTriggered:root.showDoctor(1)}
        PlasmaComponents.MenuSeparator {}
        Components.ActionMenuDelegate {text:i18n("Cleanup");enabled:false}
        Components.ActionMenuDelegate {text:i18n("Clean dangling images…");icon.source:Qt.resolvedUrl(ActionIcons.path("edit-delete"));enabled:root.backend.engineActive&&!root.backend.readOnly&&!root.backend.isPodman;onTriggered:root.showDoctor(3,"images")}
        Components.ActionMenuDelegate {text:i18n("Clean build cache…");icon.source:Qt.resolvedUrl(ActionIcons.path("edit-delete"));enabled:root.backend.engineActive&&!root.backend.readOnly&&!root.backend.isPodman;onTriggered:root.showDoctor(3,"cache")}
        Components.ActionMenuDelegate {text:i18n("Review other cleanup…");icon.source:Qt.resolvedUrl(ActionIcons.path("configure"));enabled:root.backend.engineActive&&!root.backend.readOnly&&!root.backend.isPodman;onTriggered:dialogs.confirmPrune()}
    }

    PlasmaComponents.Menu {
        id: detailMenu
        delegate: Components.ActionMenuDelegate { width: parent ? parent.width : implicitWidth }
        Instantiator {
            model: root.detailNames
            delegate: Components.ActionMenuDelegate {
                required property int index
                required property string modelData
                text: modelData
                checkable: true
                autoExclusive: true
                checked: root.detailLevel === index
                onTriggered: root.selectDetail(index)
            }
            onObjectAdded: function(index, object) { detailMenu.insertItem(index, object) }
            onObjectRemoved: function(index, object) { detailMenu.removeItem(object) }
        }
    }

    PlasmaComponents.Menu {
        id: toolbarViewsMenu
        objectName: "toolbarViewsMenu"
        delegate: Components.ActionMenuDelegate { width: parent ? parent.width : implicitWidth }
        Instantiator {
            model: root.viewChoices
            delegate: Components.ActionMenuDelegate {
                required property var modelData
                text: modelData.label
                icon.name: ""
                icon.source: Qt.resolvedUrl(ActionIcons.path(modelData.icon))
                checkable: true
                autoExclusive: true
                checked: root.viewMode === modelData.mode
                onTriggered: root.selectView(modelData.mode)
            }
            onObjectAdded: function(index, object) { toolbarViewsMenu.insertItem(index, object) }
            onObjectRemoved: function(index, object) { toolbarViewsMenu.removeItem(object) }
        }
    }
    PlasmaComponents.Menu {
        id: toolbarSortMenu
        delegate: Components.ActionMenuDelegate { width: parent ? parent.width : implicitWidth }
        Instantiator {
            model: root.sortChoices
            delegate: Components.ActionMenuDelegate {
                required property var modelData
                text: modelData.label
                checkable: true
                checked: root.cfg.sortRole === modelData.role
                onTriggered: root.selectSort(modelData.role)
            }
            onObjectAdded: function(index, object) { toolbarSortMenu.insertItem(index, object) }
            onObjectRemoved: function(index, object) { toolbarSortMenu.removeItem(object) }
        }
        PlasmaComponents.MenuSeparator {}
        Components.ActionMenuDelegate {
            text: root.cfg.sortAscending ? i18n("Switch to descending order") : i18n("Switch to ascending order")
            icon.name: ""
            icon.source: Qt.resolvedUrl(ActionIcons.path(root.cfg.sortAscending ? "go-down" : "go-up"))
            onTriggered: root.cfg.sortAscending = !root.cfg.sortAscending
        }
    }

    readonly property var candidateTargets: backend.revision >= 0 ? backend.updateTargets(allRunning.checked, includeStopped.checked) : []
    property var updateSelection: ({})
    readonly property var reviewedTargets: candidateTargets.filter(function(rec) { return root.updateSelection[rec.id] !== false })
    function canRecreate(rec) { return !!(rec.project && rec.service && backend.canUseCompose) }
    function refreshReviewButton() {
        if (!reviewUpdates.opened) return
        const button = reviewUpdates.standardButton(QQC2.Dialog.Ok)
        button.enabled = reviewedTargets.length > 0 && !backend.batchUpdating && !backend.readOnly
        const recreates = reviewedTargets.filter(canRecreate).length
        button.text = recreates === reviewedTargets.length ? i18np("Update %1 container", "Update %1 containers", recreates)
            : recreates === 0 ? i18np("Pull %1 image", "Pull %1 images", reviewedTargets.length)
            : i18np("Run %1 action", "Run %1 actions", reviewedTargets.length)
    }
    onReviewedTargetsChanged: refreshReviewButton()
    QQC2.Dialog {
        id: reviewUpdates
        objectName: "updateReviewDialog"
        title: i18n("Review image updates")
        modal: true
        anchors.centerIn: parent
        width: Math.min(root.width - 24, Kirigami.Units.gridUnit * 36)
        height: Math.min(root.height - 24, Kirigami.Units.gridUnit * 31)
        standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel
        onOpened: { root.updateSelection = ({}); root.refreshReviewButton() }
        onAccepted: {
            var generation = root.backend.generation
            var requestId = root.backend.newOutputRequest("batch", "")
            root.showOutput(i18n("Update results"), i18n("Starting…"), false, "", "batch", requestId, generation)
            root.backend.updateMany(root.reviewedTargets)
        }
        contentItem: ColumnLayout {
            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Label {
                    Layout.fillWidth: true; Layout.minimumWidth: 0
                    text: root.backend.updateRunning ? i18n("Checking image updates…") : root.backend.updateState.__checked
                        ? i18n("Last checked: %1", new Date(root.backend.updateState.__checked).toLocaleString()) : i18n("Not checked yet")
                    wrapMode: Text.Wrap
                    font: Kirigami.Theme.smallFont
                }
                Components.ActionButton {
                    text: i18n("Check now"); glyph: "package-search"
                    enabled: root.backend.engineActive && root.backend.buildxAvailable && !root.backend.updateRunning
                    onClicked: root.checkUpdates()
                }
            }
            QQC2.CheckBox { id: allRunning; text: i18n("Include containers without an update badge"); onToggled: root.refreshReviewButton() }
            QQC2.CheckBox { id: includeStopped; text: i18n("Include stopped containers · keep them stopped"); onToggled: root.refreshReviewButton() }
            QQC2.ScrollView {
                Layout.fillWidth: true; Layout.fillHeight: true; contentWidth: availableWidth
                ListView {
                    id: updateRows
                    model: root.candidateTargets
                    clip: true
                    delegate: QQC2.ItemDelegate {
                        id: updateRow
                        required property var modelData
                        width: ListView.view.width
                        contentItem: RowLayout {
                            QQC2.CheckBox {
                                checked: root.updateSelection[updateRow.modelData.id] !== false
                                Accessible.name: i18n("Select %1", updateRow.modelData.name)
                                onToggled: { var next = Object.assign({}, root.updateSelection); next[updateRow.modelData.id] = checked; root.updateSelection = next }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; Layout.minimumWidth: 0; spacing: 1
                                PlasmaComponents.Label { Layout.fillWidth: true; text: updateRow.modelData.name; font.bold: true; elide: Text.ElideRight }
                                PlasmaComponents.Label { Layout.fillWidth: true; text: updateRow.modelData.image; font: Kirigami.Theme.smallFont; elide: Text.ElideMiddle }
                                PlasmaComponents.Label {
                                    Layout.fillWidth: true; font: Kirigami.Theme.smallFont; wrapMode: Text.Wrap
                                    text: (updateRow.modelData.updateAvailable ? i18n("Update available") : String(updateRow.modelData.updateState || i18n("Not checked"))) + " · "
                                        + (root.canRecreate(updateRow.modelData) ? (updateRow.modelData.isRunning ? i18n("Pull and recreate · keep running") : i18n("Pull and recreate · leave stopped")) : i18n("Pull image only · container unchanged"))
                                }
                            }
                        }
                        HoverHandler { id: updateHover }
                        PlasmaComponents.ToolTip { visible: updateHover.hovered; text: updateRow.modelData.name + "\n" + updateRow.modelData.image }
                    }
                    Kirigami.PlaceholderMessage {
                        anchors.centerIn: parent; width: parent.width - 16
                        visible: updateRows.count === 0
                        text: root.backend.updateRunning ? i18n("Checking…") : i18n("No update candidates. Check now or include containers without a badge.")
                    }
                }
            }
        }
    }
    QQC2.Dialog {
        id: saveViewDialog
        title: i18n("Save current view")
        anchors.centerIn: parent
        modal: true
        standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel
        onAccepted: {
            if (!savedViewName.text.trim()) return
            var list = Profiles.parseViews(root.cfg.savedViews)
            list.push({name: savedViewName.text.trim(), search: root.searchText, mode: root.viewMode, detailLevel: root.detailLevel, problems: root.problemsOnly, state: root.stateFilter})
            root.cfg.savedViews = JSON.stringify(list)
            savedViewName.clear()
        }
        QQC2.TextField { id: savedViewName; placeholderText: i18n("View name"); width: Kirigami.Units.gridUnit * 18 }
    }
    Connections {
        target: root.backend
        function onBatchStatusChanged() {
            if (root.outputPageRef && root.outputPageRef.pageTitle === i18n("Update results"))
                root.outputPageRef.content = root.backend.batchResults.join("\n\n") + "\n\n" + root.backend.batchStatus
        }
    }

    // ----------------------------------------------------- keyboard ----
    Shortcut { enabled: root.visible; sequences: ["Ctrl+F"]; onActivated: root.openSearch() }
    Shortcut { enabled: root.visible; sequences: ["Ctrl+R", "F5"]; onActivated: root.refreshNow() }
    Shortcut { enabled: root.visible; sequences: ["Ctrl+1"]; onActivated: root.selectView(0) }
    Shortcut { enabled: root.visible; sequences: ["Ctrl+2"]; onActivated: root.selectView(1) }
    Shortcut { enabled: root.visible; sequences: ["Ctrl+3"]; onActivated: root.selectView(2) }
    Shortcut { enabled: root.visible; sequences: ["Ctrl+4"]; onActivated: root.selectView(3) }
    Shortcut { enabled: root.visible; sequences: ["Ctrl+Shift+A"]; onActivated: root.problemsOnly = !root.problemsOnly }
    Shortcut {
        enabled: root.visible
        // The search popup handles Escape itself; elsewhere clear filters, then go back.
        sequences: ["Escape"]
        onActivated: {
            if (searchPopup.opened) searchPopup.close()
            else if (root.searchText !== "") root.searchText = ""
            else if (root.problemsOnly) root.problemsOnly = false
            else if (root.stateFilter !== "all") root.stateFilter = "all"
            else if (stack.depth > 1) stack.pop()
        }
    }

    /* "Updated 12 seconds ago" for the refresh button's tooltip. */
    function updatedText() {
        var ms = root.backend.lastUpdatedMs
        if (ms <= 0) return i18n("Refresh")
        var secs = Math.max(0, Math.round((Date.now() - ms) / 1000))
        return secs < 2 ? i18n("Refresh — just updated")
                        : i18n("Refresh — updated %1 ago", secs < 90 ? i18np("%1 second", "%1 seconds", secs)
                                                                     : i18np("%1 minute", "%1 minutes", Math.round(secs / 60)))
    }

    function showDetail(recordId, initialTab) {
        var page = stack.push(Qt.resolvedUrl("DetailPage.qml"), {
            "backend": root.backend,
            "dialogs": dialogs,
            "navigator": stack,
            "recordId": recordId,
            "tab": initialTab || 0
        })
        // The detail page raises this instead of holding a reference to the
        // stack, so it stays usable if the stack is ever re-parented (which is
        // exactly what detaching does).
        if (page) {
            page.outputRequested.connect(function (title, text, isLive, id, kind, requestId, generation) {
                root.showOutput(title, text, isLive, id, kind, requestId, generation)
            })
        }
    }

    /*
     * Opening output for a container that already has an output page on screen
     * updates that page instead of stacking a second copy on top of it.
     *
     * A reference is held rather than testing `stack.currentItem` for a
     * marker property: StackView types currentItem as a bare QQuickItem, so
     * reaching the OutputPage API through it is untyped, while a `var`
     * reference is checked by identity and stays honest.
     */
    property var outputPageRef: null

    function showOutput(title, text, isLive, recordId, kind, requestId, requestGeneration) {
        var prepared = root.backend.outputRequestPending ? root.backend.latestOutputRequest : null
        var matchesPrepared = prepared && prepared.generation === root.backend.generation
            && prepared.recordId === (recordId || "")
        var outputKind = kind || (matchesPrepared ? prepared.kind : (isLive ? "logs" : "compose"))
        var outputId = requestId || (matchesPrepared ? prepared.requestId : "")
        if (!outputId) outputId = root.backend.newOutputRequest(outputKind, recordId || "")
        var generation = requestGeneration === undefined
            ? (matchesPrepared ? prepared.generation : root.backend.generation) : requestGeneration
        if (outputKind === "batch") root.backend.activeBatchRequestId = outputId
        if (root.outputPageRef !== null && stack.currentItem === root.outputPageRef) {
            root.outputPageRef.setContent(title, text, isLive === true, recordId || "",
                                          outputKind, outputId, generation)
            if (isLive === true) root.outputPageRef.refresh()
            return
        }
        root.outputPageRef = stack.push(Qt.resolvedUrl("OutputPage.qml"), {
            "navigator": stack,
            "backend": root.backend,
            "pageTitle": title,
            "content": text,
            "live": isLive === true,
            "recordId": recordId || "",
            "requestKind": outputKind,
            "requestId": outputId,
            "requestGeneration": generation
        })
    }

    // ========================================================== chrome ====

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ------------------------------------------------ header -------
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: headerRow.implicitHeight + Kirigami.Units.smallSpacing * 2
            visible: root.cfg.showHeader
            color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface1)
        RowLayout {
            id: headerRow
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing
            Components.ActionToolButton {
                id: backButton
                text: stack.depth > 2 ? i18n("Back to previous page") : i18n("Back to containers")
                glyph: "go-previous"
                visible: stack.depth > 1
                onClicked: stack.pop()
            }
            RowLayout {
                objectName: "toolbarFlow"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: Kirigami.Units.smallSpacing
                RowLayout {
                    id: primaryControls
                    spacing: Kirigami.Units.smallSpacing / 2
                    RowLayout {
                        visible: root.onHome
                        spacing: Kirigami.Units.smallSpacing / 2
                        Components.ToolbarButton {
                            id: viewButton
                            menuOpen: toolbarViewsMenu.opened
                            presentation: root.toolbarStyle
                            glyph: (root.viewChoices.find(function(v) { return v.mode === root.viewMode }) || root.viewChoices[0]).icon
                            label: i18n("View")
                            text: i18n("Change container view")
                            menuIndicator: true
                            onClicked: toolbarViewsMenu.popup(this, 0, height)
                        }
                        Components.ToolbarButton {
                            id: detailButton
                            menuIndicator: true
                            menuOpen: detailMenu.opened
                            presentation: root.toolbarStyle
                            visible: root.directDetail
                            glyph: "view-visible"
                            label: i18n("Detail")
                            text: i18n("Detail level: %1", root.detailNames[root.detailLevel])
                            onClicked: detailMenu.popup(this, 0, height)
                        }
                    }
                    Components.ToolbarSeparator { visible: root.onHome && (root.directFilter || root.directSort || root.directSearch) }
                    RowLayout {
                        visible: root.onHome && (root.directFilter || root.directSort || root.directSearch)
                        spacing: Kirigami.Units.smallSpacing / 2
                        Components.ToolbarButton {
                            id: filterButton
                            menuIndicator: true
                            presentation: root.toolbarStyle
                            visible: root.directFilter
                            glyph: "view-filter"
                            label: i18n("Filter")
                            text: i18n("Filter: %1", root.stateFilterLabel)
                            checkable: true
                            checked: root.activeFilterCount > 0
                            badgeText: root.activeFilterCount > 0 ? String(root.activeFilterCount) : ""
                            menuOpen: stateMenu.opened
                            onClicked: stateMenu.popup(this, 0, height)
                        }
                        Components.ToolbarButton {
                            id: sortButton
                            menuIndicator: true
                            menuOpen: toolbarSortMenu.opened
                            presentation: root.toolbarStyle
                            visible: root.directSort
                            glyph: "view-sort-ascending"
                            label: i18n("Sort")
                            text: i18n("Sort containers")
                            onClicked: toolbarSortMenu.popup(this, 0, height)
                        }
                        Components.ActionToolButton {
                            id: clearFilterButton
                            visible: root.directFilter && root.activeFilterCount > 0
                            glyph: "edit-clear"
                            text: i18n("Clear all filters")
                            onClicked: root.clearFilters()
                        }
                        Components.ToolbarButton {
                            id: searchButton
                            menuOpen: searchPopup.opened
                            presentation: root.toolbarStyle
                            visible: root.directSearch
                            glyph: "edit-find"
                            label: i18n("Search")
                            text: i18n("Search containers")
                            checkable: true
                            checked: searchPopup.opened || root.searchText !== ""
                            onClicked: root.openSearch()
                        }
                    }
                }
                Item { Layout.fillWidth: true; Layout.minimumWidth: 0 }
                RowLayout {
                    id: actionControls
                    spacing: Kirigami.Units.smallSpacing / 2
                    /* Say which host is being driven; a remote engine is easy to forget. */
                    Rectangle {
                        visible: root.backend.contextName !== "" || root.backend.remoteEngine
                        implicitWidth: hostRow.implicitWidth + Kirigami.Units.smallSpacing * 2
                        implicitHeight: hostRow.implicitHeight + Kirigami.Units.smallSpacing
                        radius: Kirigami.Units.smallSpacing
                        color: Qt.alpha(Kirigami.Theme.neutralTextColor, Style.ALPHA.tintWeak)
                        border.color: Qt.alpha(Kirigami.Theme.neutralTextColor, Style.ALPHA.borderAccent)
                        RowLayout {
                            id: hostRow
                            anchors.centerIn: parent
                            spacing: Kirigami.Units.smallSpacing / 2
                            Components.ActionIcon { glyph: "network-server"; color: Kirigami.Theme.neutralTextColor; implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: implicitWidth }
                            PlasmaComponents.Label { text: root.backend.contextName !== "" ? root.backend.contextName : i18n("Remote host"); font: Kirigami.Theme.smallFont }
                        }
                        Accessible.name: i18n("Connected to %1", root.backend.contextName !== "" ? root.backend.contextName : i18n("a remote host"))
                    }
                    RowLayout {
                        visible: root.directNew || root.directResources || root.directDoctor || root.directMaintain
                        spacing: Kirigami.Units.smallSpacing / 2
                        Components.ToolbarButton {
                            id: newButton
                            presentation: root.toolbarStyle
                            label: i18n("New")
                            text: i18n("Images and new containers…")
                            glyph: "package-plus"
                            visible: root.directNew
                            enabled: root.backend.engineActive && !root.backend.readOnly
                            onClicked: root.showDeployment()
                        }
                        Components.ToolbarButton {
                            id: resourcesButton
                            presentation: root.toolbarStyle
                            label: i18n("Resources")
                            text: i18n("Images, volumes and networks")
                            glyph: "boxes"
                            visible: root.directResources
                            enabled: root.backend.engineActive
                            onClicked: root.showResources()
                        }
                        Components.ToolbarButton {
                            id: doctorButton
                            presentation: root.toolbarStyle
                            label: i18n("Doctor")
                            text: i18n("Open Doctor")
                            glyph: "stethoscope"
                            visible: root.directDoctor
                            onClicked: root.showDoctor(0)
                        }
                        Components.ToolbarButton {
                            id: maintainButton
                            presentation: root.toolbarStyle
                            label: i18n("Maintain")
                            menuIndicator: true
                            text: i18n("Updates, diagnostics and cleanup")
                            glyph: "wrench"
                            visible: root.directMaintain
                            menuOpen: maintainMenu.opened
                            onClicked: maintainMenu.popup(this,0,height)
                        }
                    }
                    Components.ToolbarSeparator { visible: root.directNew || root.directResources || root.directDoctor || root.directMaintain }
                    RowLayout {
                        spacing: Kirigami.Units.smallSpacing / 2
                        Components.ToolbarButton {
                            id: refreshButton
                            presentation: root.toolbarStyle
                            glyph: "view-refresh"
                            label: i18n("Refresh")
                            text: root.updatedText()
                            visible: root.directRefresh
                            enabled: !root.backend.refreshing
                            onClicked: root.refreshNow()
                        }
                        Components.ToolbarButton {
                            id: detachButton
                            presentation: root.toolbarStyle
                            label: root.applet.detached ? i18n("Attach") : i18n("Detach")
                            text: root.applet.detached ? i18n("Return to panel popup") : i18n("Open in a separate window")
                            glyph: "square-arrow-out-up-right"
                            visible: root.directDetach
                            onClicked: root.applet.toggleDetached()
                        }
                        Components.ToolbarButton {
                            id: toolsButton
                            menuOpen: toolsMenu.opened
                            presentation: root.toolbarStyle
                            glyph: "application-menu"
                            label: i18n("More")
                            text: i18n("More actions")
                            onClicked: {
                                root.backend.fetchContexts()
                                toolsMenu.popup(toolsButton, 0, toolsButton.height)
                            }
                        PlasmaComponents.Menu {
                            id: toolsMenu
                            objectName: "toolbarOverflowMenu"
                            delegate: Components.ActionMenuDelegate { width: parent ? parent.width : implicitWidth }



                            Components.ActionMenuDelegate {
                                visible: !root.directFilter
                                text: i18n("Filter containers…")
                                icon.source: Qt.resolvedUrl(ActionIcons.path("view-filter"))
                                onTriggered: stateMenu.popup(toolsButton, 0, toolsButton.height)
                            }
                            Components.ActionMenuDelegate {
                                visible: !root.directSort
                                text: i18n("Sort containers…")
                                icon.source: Qt.resolvedUrl(ActionIcons.path("view-sort-ascending"))
                                onTriggered: toolbarSortMenu.popup(toolsButton, 0, toolsButton.height)
                            }
                            Components.ActionMenuDelegate {
                                visible: !root.directSearch
                                text: i18n("Search containers…")
                                icon.source: Qt.resolvedUrl(ActionIcons.path("edit-find"))
                                onTriggered: root.openSearch()
                            }
                            Components.ActionMenuDelegate {
                                visible: !root.directRefresh
                                text: i18n("Refresh")
                                icon.source: Qt.resolvedUrl(ActionIcons.path("view-refresh"))
                                enabled: !root.backend.refreshing
                                onTriggered: root.refreshNow()
                            }
                            Components.ActionMenuDelegate {
                                visible: !root.directNew
                                icon.name: ""
                                icon.source: Qt.resolvedUrl(ActionIcons.path("list-add"))
                                text: i18n("Images and new containers…")
                                enabled: root.backend.engineActive && !root.backend.readOnly
                                onTriggered: root.showDeployment()
                            }
                            Components.ActionMenuDelegate {
                                visible: !root.directDetail
                                icon.name: ""
                                icon.source: Qt.resolvedUrl(ActionIcons.path("view-visible"))
                                text: i18n("Detail: %1", root.detailNames[root.detailLevel])
                                onTriggered: detailMenu.popup(toolsButton, 0, toolsButton.height)
                            }
                            Components.ActionMenuDelegate {
                                visible: root.backend.problemCount > 0 || root.problemsOnly
                                icon.name: ""
                                icon.source: Qt.resolvedUrl(ActionIcons.path("dialog-warning"))
                                text: i18n("Only containers that need attention")
                                checkable: true
                                checked: root.problemsOnly
                                onTriggered: root.problemsOnly = !root.problemsOnly
                            }
                            Components.ActionMenuDelegate {
                                visible: !root.directResources
                                icon.name: ""
                                icon.source: Qt.resolvedUrl(ActionIcons.path("drive-harddisk"))
                                text: i18n("Images, volumes and networks…")
                                enabled: root.backend.engineActive
                                onTriggered: root.showResources()
                            }
                            Components.ActionMenuDelegate {
                                text: i18n("Activity log")
                                icon.source: Qt.resolvedUrl(ActionIcons.path("bell-ring"))
                                onTriggered: root.showActivity()
                            }
                            Components.ActionMenuDelegate {
                                visible: !root.directDoctor
                                text: i18n("Open Doctor")
                                icon.source: Qt.resolvedUrl(ActionIcons.path("utilities-system-monitor"))
                                onTriggered: root.showDoctor(0)
                            }
                            Components.ActionMenuDelegate {
                                visible: !root.directMaintain
                                text: i18n("Maintain") + " ▾"
                                icon.source: Qt.resolvedUrl(ActionIcons.path("configure"))
                                onTriggered: maintainMenu.popup(toolsButton,0,toolsButton.height)
                            }
                            Components.ActionMenuDelegate {
                                icon.name: ""
                                icon.source: Qt.resolvedUrl(ActionIcons.path("edit-clear"))
                                text: i18n("Clear filters")
                                visible: root.searchText !== "" || root.problemsOnly || root.stateFilter !== "all"
                                onTriggered: { root.searchText = ""; root.problemsOnly = false; root.stateFilter = "all" }
                            }
                            PlasmaComponents.MenuSeparator {
                                visible: !root.directFilter || !root.directSort || !root.directSearch || !root.directRefresh
                                    || !root.directNew || !root.directDetail || !root.directResources || !root.directMaintain
                                    || root.backend.problemCount > 0 || root.problemsOnly || root.searchText !== "" || root.stateFilter !== "all"
                                height: visible ? implicitHeight : 0
                            }
                            PlasmaComponents.Menu {
                                id: savedViewMenu
                                delegate: Components.ActionMenuDelegate { width: parent ? parent.width : implicitWidth }
                                title: i18n("Saved views")
                                icon.name: ""
                                icon.source: Qt.resolvedUrl(ActionIcons.path("bookmark"))
                                Instantiator {
                                    model: Profiles.parseViews(root.cfg.savedViews)
                                    delegate: Components.ActionMenuDelegate {
                                        required property var modelData
                                        text: modelData.name
                                        onTriggered: { root.searchText = modelData.search; root.selectView(modelData.mode); root.selectDetail(modelData.detailLevel); root.problemsOnly = modelData.problems; root.stateFilter = modelData.state || "all" }
                                    }
                                    onObjectAdded: function(index, object) { savedViewMenu.insertItem(index, object) }
                                    onObjectRemoved: function(index, object) { savedViewMenu.removeItem(object) }
                                }
                                PlasmaComponents.MenuSeparator {
                                    visible: Profiles.parseViews(root.cfg.savedViews).length > 0
                                    height: visible ? implicitHeight : 0
                                }
                                Components.ActionMenuDelegate { text: i18n("Save this view…"); onTriggered: saveViewDialog.open() }
                                Components.ActionMenuDelegate { text: i18n("Clear saved views…"); onTriggered: dialogs.confirm(i18n("Clear saved views?"), i18n("Only saved view shortcuts are removed."), function() { root.cfg.savedViews = "[]" }) }
                            }
                            PlasmaComponents.Menu {
                                id: toolbarStyleMenu
                                title: i18n("Toolbar labels")
                                icon.source: Qt.resolvedUrl(ActionIcons.path("view-list-text"))
                                delegate: Components.ActionMenuDelegate {}
                                Instantiator {
                                    model: [i18n("Icons only"), i18n("Text beside icons"), i18n("Text only"), i18n("Text below icons")]
                                    delegate: Components.ActionMenuDelegate {
                                        required property int index
                                        required property string modelData
                                        text: modelData
                                        icon.source: Qt.resolvedUrl(ActionIcons.path("view-list-text"))
                                        checkable: true
                                        checked: root.toolbarStyle === index
                                        onTriggered: root.cfg.toolbarStyle = index
                                    }
                                    onObjectAdded: function(index, object) { toolbarStyleMenu.insertItem(index, object) }
                                    onObjectRemoved: function(index, object) { toolbarStyleMenu.removeItem(object) }
                                }
                            }
                            PlasmaComponents.MenuSeparator {}
                            PlasmaComponents.Menu {
                                id: hostMenu
                                delegate: Components.ActionMenuDelegate { width: parent ? parent.width : implicitWidth }
                                title: i18n("Host")
                                icon.name: ""
                                icon.source: Qt.resolvedUrl(ActionIcons.path("network-server"))
                                Components.ActionMenuDelegate { text: i18n("Default"); checkable: true; checked: root.backend.contextName === ""; onTriggered: root.backend.setContext("") }
                                Instantiator {
                                    model: root.backend.contexts.filter(function(c) { return c !== "default" })
                                    delegate: Components.ActionMenuDelegate {
                                        required property string modelData
                                        text: modelData
                                        checkable: true
                                        checked: root.backend.contextName === modelData
                                        onTriggered: root.backend.setContext(modelData)
                                    }
                                    onObjectAdded: function(index, object) { hostMenu.insertItem(index + 1, object) }
                                    onObjectRemoved: function(index, object) { hostMenu.removeItem(object) }
                                }
                            }
                            Components.ActionMenuDelegate {
                                visible: !root.directDetach
                                icon.name: ""
                                icon.source: Qt.resolvedUrl(ActionIcons.path("window-new"))
                                text: i18n("Open in a separate window")
                                onTriggered: root.applet.toggleDetached()
                            }
                            Components.ActionMenuDelegate {
                                visible: !root.backend.engineActive && root.backend.canControlService && !root.backend.readOnly
                                icon.name: ""
                                icon.source: Qt.resolvedUrl(ActionIcons.path("media-playback-start"))
                                text: i18n("Start the %1 service", root.backend.engineName)
                                onTriggered: root.backend.startEngine()
                            }
                            Components.ActionMenuDelegate {
                                visible: root.backend.engineActive && root.backend.canControlService && !root.backend.readOnly
                                icon.name: ""
                                icon.source: Qt.resolvedUrl(ActionIcons.path("system-shutdown"))
                                text: i18n("Stop the %1 service…", root.backend.engineName)
                                onTriggered: confirmStopEngine.open()
                            }
                            Components.ActionMenuDelegate {
                                icon.name: ""
                                icon.source: Qt.resolvedUrl(ActionIcons.path("configure"))
                                text: i18n("Configure Dockmoid…")
                                onTriggered: root.applet.configure()
                            }
                        }
                        }
                    }
                }
            }
        }

        }
        Kirigami.Separator { Layout.fillWidth: true; visible: root.cfg.showHeader }

        // --------------------------------------------- startup bar ------
        PlasmaComponents.ProgressBar {
            id: activityBar
            Layout.fillWidth: true
            visible: root.cfg.showActivityBar && root.backend.refreshing
                && !root.backend.engineKnown
            implicitHeight: visible ? Math.max(2, Kirigami.Units.smallSpacing / 2) : 0
            from: 0
            to: 100
            value: 50
            topInset: 0
            bottomInset: 0
        }

        // ------------------------------------------------- error --------
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            visible: text !== ""
            text: root.backend.actionError || root.backend.lastError || (root.backend.readOnly ? i18n("Read-only monitoring mode") : "")
            type: root.backend.actionError || root.backend.lastError ? Kirigami.MessageType.Error : Kirigami.MessageType.Information
            showCloseButton: true
        }

        // -------------------------------------------------- stack --------
        QQC2.StackView {
            id: stack
            Layout.fillWidth: true
            Layout.fillHeight: true
            // Docker unreachable: say why, over the (empty) list.
            Components.EnginePlaceholder {
                parent: stack
                anchors.fill: parent
                z: 5
                visible: root.backend.engineKnown && !root.backend.engineActive && stack.depth === 1
                backend: root.backend
            }

            initialItem: HomePage {
                backend: root.backend
                stateFilter: root.stateFilter
                problemsOnly: root.problemsOnly
                onFilterRequested: function(state) { root.stateFilter = (state === "all" || root.stateFilter === state) ? "all" : state; root.problemsOnly = false }
                onAttentionRequested: { root.problemsOnly = !root.problemsOnly; root.stateFilter = "all" }
                onUpdatesRequested: reviewUpdates.open()
                onViewRequested: function(mode) { root.selectView(mode) }
                onActivityRequested: root.showActivity()
                onClearFiltersRequested: root.clearFilters()
                proxy: proxy
                dialogs: dialogs
                viewMode: root.viewMode
                detailLevel: root.detailLevel
                searchText: root.searchText
                rowFilter: root.rowFilter
                activeFilterCount: root.activeFilterCount
                onCreateRequested: root.showDeployment()
                onResourcesRequested:root.showResources()
                onOpenDetail: function (recordId) { root.showDetail(recordId) }
                onOpenOutput: function (title, text, isLive, recordId) {
                    root.showOutput(title, text, isLive, recordId)
                }
            }
        }

        // --------------------------------------------- status bar --------
        Kirigami.Separator { Layout.fillWidth: true; visible: root.cfg.showStatusBar }
        Components.StatusBar {
            Layout.fillWidth: true
            showCounts: stack.depth > 1
            visible: root.cfg.showStatusBar
            backend: root.backend
            onAttentionFilterRequested: {root.problemsOnly=!root.problemsOnly;root.stateFilter="all";root.searchText="";if(stack.depth>1)stack.pop(stack.get(0))}
            onCountFilter: function(state) { root.stateFilter = state; root.searchText = ""; root.problemsOnly = false; if (stack.depth > 1) stack.pop(stack.get(0)) }
        }
    }


    /*
     * One set of confirmation dialogs for the whole view, living above
     * everything including the stack. A dialog owned by a delegate inside the
     * stack would be buried the moment a detail page is pushed on top of it.
     */
    Components.ActionDialogs {
        id: dialogs
        anchors.fill: parent
        backend: root.backend
        onRunRequested: function(recordId) { root.showDetail(recordId, 3) }
    }

    // ------------------------------------------------------ dialogs ------

    QQC2.Dialog {
        id: confirmStopEngine
        title: i18n("Stop %1?", root.backend.engineName)
        modal: true
        anchors.centerIn: parent
        standardButtons: QQC2.Dialog.Yes | QQC2.Dialog.No
        onOpened: { standardButton(QQC2.Dialog.Yes).text = i18n("Stop %1", root.backend.engineName); standardButton(QQC2.Dialog.No).text = i18n("Cancel") }
        onAccepted: root.backend.stopEngine()

        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            PlasmaExtras.Heading {
                Layout.fillWidth: true
                level: 3
                text: i18n("Stop the %1 service?", root.backend.engineName)
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 22
                wrapMode: Text.WordWrap
                text: i18n("Every running container will be stopped. Services you depend on may go down.")
            }
        }
    }
}
