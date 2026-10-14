import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

import "../components" as Components

/*
 * PopupView — the whole expanded UI, in a form that works unchanged both
 * inside the applet popup and inside the detached window.
 *
 * Layout:
 *   header      engine summary, search, view switcher, detail level, actions
 *   activity    thin bar showing time until the next poll
 *   error       inline message for the last failed command
 *   stack       home (list/table/compose) -> detail -> output
 *   status bar  running/stopped/images/cpu/mem totals
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
    property int detailLevel: cfg.defaultDetailLevel
    readonly property var detailNames: [i18n("Minimal"), i18n("Normal"), i18n("Detailed"), i18n("Everything")]
    property string searchText: ""
    /* Show only what needs attention: unhealthy, restarting, crashed or paused. */
    property bool problemsOnly: false

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
        var source = root.backend.containerModel
        return function (sourceRow) {
            var row = source.get(sourceRow)
            if (!row) return false
            if (problems && !root.backend.isProblem(row)) return false
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
        stack.push(Qt.resolvedUrl("ResourcesPage.qml"), {
            "backend": root.backend,
            "dialogs": dialogs,
            "navigator": stack
        })
    }

    // ----------------------------------------------------- keyboard ----
    Shortcut { sequences: ["Ctrl+F"]; onActivated: searchField.forceActiveFocus() }
    Shortcut { sequences: ["Ctrl+R", "F5"]; onActivated: root.refreshNow() }
    Shortcut { sequences: ["Ctrl+1"]; onActivated: root.viewMode = 0 }
    Shortcut { sequences: ["Ctrl+2"]; onActivated: root.viewMode = 1 }
    Shortcut { sequences: ["Ctrl+3"]; onActivated: root.viewMode = 2 }
    Shortcut { sequences: ["Ctrl+Shift+A"]; onActivated: root.problemsOnly = !root.problemsOnly }
    Shortcut {
        // Escape peels one layer: clear the search, then go back a page.
        sequences: ["Escape"]
        onActivated: {
            if (searchField.text !== "") searchField.clear()
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

    function showDetail(recordId) {
        var page = stack.push(Qt.resolvedUrl("DetailPage.qml"), {
            "backend": root.backend,
            "dialogs": dialogs,
            "navigator": stack,
            "recordId": recordId
        })
        // The detail page raises this instead of holding a reference to the
        // stack, so it stays usable if the stack is ever re-parented (which is
        // exactly what detaching does).
        if (page) {
            page.outputRequested.connect(function (title, text, isLive) {
                root.showOutput(title, text, isLive, recordId)
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

    function showOutput(title, text, isLive, recordId) {
        if (root.outputPageRef !== null && stack.currentItem === root.outputPageRef) {
            root.outputPageRef.setContent(title, text, isLive === true)
            root.outputPageRef.recordId = recordId || ""
            return
        }
        root.outputPageRef = stack.push(Qt.resolvedUrl("OutputPage.qml"), {
            "navigator": stack,
            "backend": root.backend,
            "pageTitle": title,
            "content": text,
            "live": isLive === true,
            "recordId": recordId || ""
        })
    }

    // ========================================================== chrome ====

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ------------------------------------------------ header -------
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            visible: root.cfg.showHeader
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: {
                    if (!root.backend.engineActive) return i18n("Docker is not running")
                    return i18np("%1 running · %2 total", "%1 running · %2 total",
                                 root.backend.running, root.backend.total)
                }
                font.bold: true
                elide: Text.ElideRight
                Layout.maximumWidth: Kirigami.Units.gridUnit * 12
                color: root.backend.engineActive
                    ? Kirigami.Theme.textColor
                    : Kirigami.Theme.negativeTextColor
            }

            PlasmaComponents.Label {
                visible: root.backend.unhealthy > 0 && root.cfg.showHealth
                text: i18np("%1 unhealthy", "%1 unhealthy", root.backend.unhealthy)
                color: Kirigami.Theme.negativeTextColor
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                elide: Text.ElideRight
            }

            Item { Layout.fillWidth: true }

            PlasmaExtras.SearchField {
                id: searchField
                Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                Layout.maximumWidth: Kirigami.Units.gridUnit * 14
                placeholderText: i18n("Search containers")
                onTextChanged: root.searchText = text
            }

            // ---- how the list is laid out: one choice of three ----------
            Row {
                spacing: 0

                Repeater {
                    model: [
                        { "mode": 0, "icon": "view-list-text",    "tip": i18n("List") },
                        { "mode": 1, "icon": "view-list-details", "tip": i18n("Table") },
                        { "mode": 2, "icon": "view-list-tree",    "tip": i18n("Grouped by Compose project") }
                    ]
                    delegate: PlasmaComponents.ToolButton {
                        required property var modelData
                        icon.name: modelData.icon
                        text: modelData.tip
                        display: PlasmaComponents.AbstractButton.IconOnly
                        checkable: true
                        checked: root.viewMode === modelData.mode
                        onClicked: root.viewMode = modelData.mode
                        PlasmaComponents.ToolTip { text: modelData.tip }
                    }
                }
            }

            // ---- how much each row says (only the list has levels) ------
            PlasmaComponents.ToolButton {
                id: detailButton
                icon.name: "view-visible"
                display: PlasmaComponents.AbstractButton.IconOnly
                text: i18n("Row detail: %1", root.detailNames[root.detailLevel])
                visible: root.viewMode === 0
                onClicked: detailMenu.popup(detailButton, 0, detailButton.height)
                PlasmaComponents.ToolTip { text: detailButton.text }

                PlasmaComponents.Menu {
                    id: detailMenu
                    Instantiator {
                        model: root.detailNames
                        delegate: PlasmaComponents.MenuItem {
                            required property int index
                            required property string modelData
                            text: modelData
                            checkable: true
                            checked: root.detailLevel === index
                            onTriggered: root.detailLevel = index
                        }
                        onObjectAdded: function (index, object) { detailMenu.insertItem(index, object) }
                        onObjectRemoved: function (index, object) { detailMenu.removeItem(object) }
                    }
                }
            }

            PlasmaComponents.BusyIndicator {
                visible: root.backend.refreshing && !root.backend.engineKnown
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: implicitWidth
            }

            PlasmaComponents.ToolButton {
                id: attentionButton
                icon.name: "dialog-warning"
                display: PlasmaComponents.AbstractButton.IconOnly
                text: i18n("Only containers that need attention")
                checkable: true
                checked: root.problemsOnly
                visible: root.backend.problemCount > 0 || root.problemsOnly
                onClicked: root.problemsOnly = !root.problemsOnly
                PlasmaComponents.ToolTip { text: attentionButton.text }
            }

            PlasmaComponents.ToolButton {
                id: refreshButton
                icon.name: "view-refresh"
                display: PlasmaComponents.AbstractButton.IconOnly
                text: i18n("Refresh")
                enabled: !root.backend.refreshing
                onClicked: root.refreshNow()
                PlasmaComponents.ToolTip { text: root.updatedText() }
            }

            PlasmaComponents.ToolButton {
                id: detachButton
                icon.name: "window-new"
                display: PlasmaComponents.AbstractButton.IconOnly
                text: i18n("Open in a separate window")
                onClicked: root.applet.toggleDetached()
                PlasmaComponents.ToolTip { text: detachButton.text }
            }

            PlasmaComponents.ToolButton {
                id: startButton
                icon.name: "media-playback-start"
                display: PlasmaComponents.AbstractButton.IconOnly
                text: i18n("Start the Docker service")
                visible: !root.backend.engineActive
                onClicked: root.backend.startEngine()
                PlasmaComponents.ToolTip { text: startButton.text }
            }

            PlasmaComponents.ToolButton {
                id: toolsButton
                icon.name: "overflow-menu"
                display: PlasmaComponents.AbstractButton.IconOnly
                text: i18n("More")
                onClicked: {
                    root.backend.fetchContexts()
                    toolsMenu.popup(toolsButton, 0, toolsButton.height)
                }
                PlasmaComponents.ToolTip { text: toolsButton.text }

                PlasmaComponents.Menu {
                    id: toolsMenu

                    PlasmaComponents.MenuItem {
                        icon.name: "drive-harddisk"
                        text: i18n("Images, volumes and networks…")
                        enabled: root.backend.engineActive
                        onTriggered: root.showResources()
                    }
                    PlasmaComponents.MenuItem {
                        icon.name: "edit-clear-history"
                        text: i18n("Clean up unused data…")
                        enabled: root.backend.engineActive
                        onTriggered: dialogs.confirmPrune()
                    }
                    PlasmaComponents.MenuItem {
                        icon.name: "package-upgrade"
                        text: i18n("Check for image updates now")
                        enabled: root.backend.engineActive && root.cfg.checkImageUpdates
                        onTriggered: { root.backend.updateState["__checked"] = 0; root.backend.startUpdateCheck() }
                    }

                    PlasmaComponents.MenuSeparator {}

                    PlasmaComponents.Menu {
                        id: hostMenu
                        title: i18n("Host")
                        icon.name: "network-server"

                        PlasmaComponents.MenuItem {
                            text: i18n("Default")
                            checkable: true
                            checked: root.backend.contextName === ""
                            onTriggered: root.backend.setContext("")
                        }
                        Instantiator {
                            model: root.backend.contexts.filter(function (c) { return c !== "default" })
                            delegate: PlasmaComponents.MenuItem {
                                required property string modelData
                                text: modelData
                                checkable: true
                                checked: root.backend.contextName === modelData
                                onTriggered: root.backend.setContext(modelData)
                            }
                            onObjectAdded: function (index, object) { hostMenu.insertItem(index + 1, object) }
                            onObjectRemoved: function (index, object) { hostMenu.removeItem(object) }
                        }
                    }

                    PlasmaComponents.Menu {
                        id: sortMenu
                        title: i18n("Sort by")
                        icon.name: "view-sort-ascending"
                        Instantiator {
                            model: [
                                { "role": "sortKey", "label": i18n("Pinned, then running") },
                                { "role": "name",    "label": i18n("Name") },
                                { "role": "cpuPct",  "label": i18n("CPU") },
                                { "role": "memPct",  "label": i18n("Memory") },
                                { "role": "project", "label": i18n("Project") }
                            ]
                            delegate: PlasmaComponents.MenuItem {
                                required property var modelData
                                text: modelData.label
                                checkable: true
                                checked: root.cfg.sortRole === modelData.role
                                onTriggered: {
                                    plasmoid.configuration.sortAscending = modelData.role !== "cpuPct" && modelData.role !== "memPct"
                                    plasmoid.configuration.sortRole = modelData.role
                                }
                            }
                            onObjectAdded: function (index, object) { sortMenu.insertItem(index, object) }
                            onObjectRemoved: function (index, object) { sortMenu.removeItem(object) }
                        }
                    }

                    PlasmaComponents.MenuSeparator {}

                    PlasmaComponents.MenuItem {
                        icon.name: "system-shutdown"
                        text: i18n("Stop the Docker service…")
                        enabled: root.backend.engineActive
                        onTriggered: confirmStopEngine.open()
                    }
                    PlasmaComponents.MenuItem {
                        icon.name: "configure"
                        text: i18n("Configure Dockmoid…")
                        onTriggered: plasmoid.internalAction("configure").trigger()
                    }
                }
            }
        }

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
            type: Kirigami.MessageType.Error
            text: root.backend.actionError || root.backend.lastError
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
                proxy: proxy
                dialogs: dialogs
                viewMode: root.viewMode
                detailLevel: root.detailLevel
                searchText: root.searchText
                rowFilter: root.rowFilter
                onOpenDetail: function (recordId) { root.showDetail(recordId) }
                onOpenOutput: function (title, text, isLive, recordId) {
                    root.showOutput(title, text, isLive, recordId)
                }
            }
        }

        // --------------------------------------------- status bar --------
        Components.StatusBar {
            Layout.fillWidth: true
            visible: root.cfg.showStatusBar
            backend: root.backend
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
    }

    // ------------------------------------------------------ dialogs ------

    QQC2.Dialog {
        id: confirmStopEngine
        title: i18n("Stop Docker?")
        modal: true
        anchors.centerIn: parent
        standardButtons: QQC2.Dialog.Yes | QQC2.Dialog.No
        onAccepted: root.backend.stopEngine()

        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            PlasmaExtras.Heading {
                Layout.fillWidth: true
                level: 3
                text: i18n("Stop the Docker service?")
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
