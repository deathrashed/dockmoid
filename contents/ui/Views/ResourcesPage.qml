pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kquickcontrolsaddons as KQuickControlsAddons

import "../components" as Components
import "../../lib/style.js" as Style
import "../../lib/actionIcons.js" as ActionIcons

/* Images, Docker volumes and networks, including verified usage and cleanup. */
Item {
    id: root

    required property var backend
    /* True when shown inside the main page's dock. */
    property bool embedded: false
    required property var dialogs
    required property var navigator

    signal openDetail(string recordId)
    /* image: a reference to put in the Configure form, or "". */
    signal deploymentRequested(int initialTab, string image)

    property int tab: 0 // images, volumes, networks
    /* A tray-sized popup: shorter tabs, a 2 x 2 summary and badges under the name. */
    readonly property bool narrow: width < Kirigami.Units.gridUnit * 26
    property bool unusedOnly: false
    property string searchText: ""
    property string sortMode: "name"
    property var relatedItem: null
    property var relatedRecords: []
    property var relatedConfiguredRecords: []

    readonly property var kinds: ["images", "volumes", "networks"]
    readonly property string kind: root.kinds[root.tab]
    readonly property var sourceItems: root.backend.resourceLists[root.kind] || []
    readonly property string resourceError: root.backend.resourceErrors[root.kind] || ""
    readonly property bool loading: root.backend.resourceLoading[root.kind] === true

    readonly property var items: {
        var rows = root.sourceItems.filter(function (item) {
            if (root.unusedOnly && !root.isUnused(item)) return false
            if (!root.matchesSearch(item)) return false
            return true
        })
        var mode = root.sortMode
        rows.sort(function (a, b) {
            if (mode === "largest") {
                const as = root.sizeBytes(a.size), bs = root.sizeBytes(b.size)
                if (as < 0 && bs >= 0) return 1
                if (bs < 0 && as >= 0) return -1
                return bs - as || root.nameCompare(a, b)
            }
            if (mode === "newest") {
                const ac = root.createdRank(a.created), bc = root.createdRank(b.created)
                if (ac < 0 && bc >= 0) return 1
                if (bc < 0 && ac >= 0) return -1
                return bc - ac || root.nameCompare(a, b)
            }
            return root.nameCompare(a, b)
        })
        return rows
    }

    readonly property var sortOptions: {
        var choices = [{key:"name", label:i18n("Name")}]
        if (root.kind === "images") choices.push({key:"newest", label:i18n("Newest")})
        if (root.kind !== "networks") choices.push({key:"largest", label:i18n("Largest")})
        return choices
    }

    function reload(force) {
        if (root.relatedItem) root.closeRelated()
        root.backend.fetchResources(root.kind,force)
    }

    function matchesSearch(item) {
        var needle = root.searchText.trim().toLowerCase()
        if (needle === "") return true
        return [item.ref, item.repository, item.tag, item.id, item.name,
                item.driver, item.scope, item.project, item.created, item.size]
            .join(" ").toLowerCase().indexOf(needle) >= 0
    }

    function nameCompare(a, b) {
        var an = String(a.ref || a.name || a.id || "").toLowerCase()
        var bn = String(b.ref || b.name || b.id || "").toLowerCase()
        return an < bn ? -1 : (an > bn ? 1 : 0)
    }

    function sizeBytes(value) {
        var match = /^\s*([\d.]+)\s*(B|KB|MB|GB|TB|PB|KiB|MiB|GiB|TiB|PiB)?\s*$/i.exec(String(value || ""))
        if (!match) return -1
        var unit = String(match[2] || "B").toUpperCase()
        var power = ({B:0,KB:1,MB:2,GB:3,TB:4,PB:5,KIB:1,MIB:2,GIB:3,TIB:4,PIB:5})[unit]
        var base = unit.indexOf("I") >= 0 ? 1024 : 1000
        return Number(match[1]) * Math.pow(base, power)
    }

    function createdRank(value) {
        var text = String(value || "")
        var date = Date.parse(text)
        if (!isNaN(date)) return date
        var ago = /(\d+(?:\.\d+)?)\s*(second|minute|hour|day|week|month|year)s?\s+ago/i.exec(text)
        if (!ago) return -1
        var factor = ({second:1000, minute:60000, hour:3600000, day:86400000,
                       week:604800000, month:2592000000, year:31536000000})[ago[2].toLowerCase()]
        return Date.now() - Number(ago[1]) * factor
    }

    function knownContainers(item) {
        return root.backend.containersForResource(root.kind, item) || []
    }

    function configuredImageRefs(item) {
        if (root.kind !== "images" || typeof root.backend.configuredForImage !== "function") return []
        var refs = root.backend.configuredForImage(item)
        return Array.isArray(refs) ? refs : []
    }

    function configuredImageCount(item) { return root.configuredImageRefs(item).length }

    function usageCount(item) {
        var reported = root.kind === "images" ? Number(item.containers)
            : (root.kind === "volumes" ? Number(item.links) : -1)
        var found = root.knownContainers(item).length
        if (reported >= 0) return Math.max(reported, found)
        if (found > 0) return found
        if (root.kind === "networks" && root.backend.lastSnapshot !== null && root.backend.engineActive) return 0
        return -1
    }

    function usageKnown(item) { return root.usageCount(item) >= 0 }
    function isUnused(item) { return root.usageKnown(item) && root.usageCount(item) === 0 && root.configuredImageCount(item) === 0 }

    function usageText(item) {
        var count = root.usageCount(item)
        if (count < 0) return i18n("Usage unknown")
        if (count === 0) return root.configuredImageCount(item) > 0 ? i18n("No existing containers") : i18n("Unused")
        return i18np("%1 container", "%1 containers", count)
    }

    function usageRowText(item) {
        var text = root.usageText(item)
        return root.usageCount(item) > 0 && root.knownContainers(item).length === 0
            ? i18n("%1 · containers not loaded", text) : text
    }

    function usageHelp(item) {
        var count = root.usageCount(item)
        if (root.configuredImageCount(item) > 0)
            return i18n("Referenced by %1 configured Compose service(s). Removing this image can make a later deployment fail.", root.configuredImageCount(item))
        if (count > 0 && root.knownContainers(item).length === 0)
            return i18n("Docker reports this resource is in use, but no matching containers are loaded.")
        if (count < 0) return i18n("Usage could not be verified. Removal stays disabled.")
        return i18n("Show the containers using this resource.")
    }

    function openRelated(item) {
        root.relatedItem = item
        root.relatedRecords = root.knownContainers(item)
        root.relatedConfiguredRecords = root.configuredImageRefs(item)
    }

    /* Inspect output or layer history, shown in the same panel as references. */
    property string infoTitle: ""
    property string infoText: ""
    function openInfo(item, what) {
        root.relatedItem = item
        root.relatedRecords = []
        root.relatedConfiguredRecords = []
        root.infoTitle = what === "history" ? i18n("Layers of %1", root.resourceTitle(item)) : i18n("Inspect %1", root.resourceTitle(item))
        root.infoText = i18n("Loading…")
        const kind = root.kind
        root.backend.resourceInfo(kind, item, what, function (text) { if (root.relatedItem === item) root.infoText = text })
    }

    /* Running containers that are, or are not, on this network. */
    function networkMembers(item, onIt) {
        return root.backend.records.filter(function (r) {
            const on = String(r.networks || "").split(",").map(function (n) { return n.trim() }).indexOf(item.name) >= 0
            return r.isRunning && r.state !== "not-created" && on === onIt
        })
    }

    property var menuItem: null
    function openItemMenu(item, anchor) {
        root.menuItem = item
        itemMenu.popup(anchor, 0, anchor.height)
    }

    function closeRelated() {
        root.infoTitle = ""
        root.infoText = ""
        root.relatedItem = null
        root.relatedRecords = []
        root.relatedConfiguredRecords = []
    }

    function resourceTitle(item) {
        return root.kind === "images" ? (item.ref || i18n("untagged image")) : item.name
    }

    function canRemove(item) {
        if (!root.backend.engineActive) return false
        if (root.backend.readOnly || root.backend.isPodman) return false
        if (root.kind === "networks" && item.builtin) return false
        return root.usageKnown(item) && root.usageCount(item) === 0 && root.configuredImageCount(item) === 0
    }

    function removeHelp(item) {
        if (!root.backend.engineActive) return i18n("The Docker engine is unavailable.")
        if (root.backend.readOnly) return i18n("Removal is disabled in read-only mode.")
        if (root.backend.isPodman) return i18n("Resource removal is unavailable for this engine.")
        if (root.kind === "networks" && item.builtin) return i18n("Built-in networks cannot be removed.")
        var count = root.usageCount(item)
        if (count < 0) return i18n("Usage is unknown, so removal stays disabled.")
        if (count > 0) return i18n("This resource is in use by %1.", root.usageText(item))
        if (root.configuredImageCount(item) > 0) return i18n("Removal is disabled because %1 configured Compose service(s) reference this image.", root.configuredImageCount(item))
        return i18n("Remove this unused resource.")
    }

    function requestRemove(item) {
        root.dialogs.confirm(
            i18n("Remove %1?", root.resourceTitle(item)),
            root.kind === "volumes"
                ? i18n("The Docker volume and everything stored in it will be deleted permanently.")
                : i18n("This cannot be undone."),
            function () { root.backend.removeResource(root.kind, item) })
    }

    function createForCurrentTab() { root.deploymentRequested(root.tab === 0 ? 0 : 3, "") }

    /* 1234567890 -> "1.23 GB", for the summary's total. */
    function formatBytes(bytes) {
        if (!(bytes > 0)) return "0 B"
        const units = ["B", "kB", "MB", "GB", "TB"]
        let i = 0
        while (bytes >= 1000 && i < units.length - 1) { bytes /= 1000; i++ }
        return (i === 0 ? String(Math.round(bytes)) : bytes.toFixed(bytes >= 100 ? 0 : bytes >= 10 ? 1 : 2)) + " " + units[i]
    }
    readonly property var summary: {
        const rows = root.sourceItems
        let used = 0, unused = 0, bytes = 0
        for (let i = 0; i < rows.length; i++) {
            if (root.isUnused(rows[i])) unused++
            else if (root.usageCount(rows[i]) > 0 || root.configuredImageCount(rows[i]) > 0) used++
            const size = root.sizeBytes(rows[i].size)
            if (size > 0) bytes += size
        }
        return {total: rows.length, used: used, unused: unused, bytes: bytes}
    }
    /* This tab's line from `docker system df`, when it has been loaded. */
    readonly property var diskLine: {
        const type = root.kind === "images" ? "Images" : root.kind === "volumes" ? "Local Volumes" : ""
        const lines = root.backend.diskUsage || []
        for (let i = 0; i < lines.length; i++) if (lines[i].type === type) return lines[i]
        return null
    }
    readonly property string kindGlyph: root.kind === "images" ? "layers" : root.kind === "volumes" ? "database" : "network"
    readonly property string createLabel: root.kind === "images" ? i18n("Pull Image…") : root.kind === "volumes" ? i18n("Create Volume…") : i18n("Create Network…")

    /* Usage reads as one badge per kind of reference, side by side. */
    component UsageBadges: Flow {
        id: badges
        required property var row
        spacing: Kirigami.Units.smallSpacing / 2
        Components.Pill {
            visible: badges.row.used > 0
            dense: true
            tone: "ok"
            glyph: "box"
            text: i18np("%1 container", "%1 containers", badges.row.used)
            opacity: badges.row.hasContainers ? 1 : 0.55
            HoverHandler { id: existingHover; cursorShape: badges.row.hasContainers ? Qt.PointingHandCursor : Qt.ArrowCursor }
            TapHandler { enabled: badges.row.hasContainers; onTapped: root.openRelated(badges.row.modelData) }
            PlasmaComponents.ToolTip { visible: existingHover.hovered; text: root.usageHelp(badges.row.modelData) }
        }
        Components.Pill {
            visible: badges.row.configured > 0
            dense: true
            tone: "amber"
            glyph: "file-code"
            text: i18n("Compose · %1", badges.row.configured)
            HoverHandler { id: configuredHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.openRelated(badges.row.modelData) }
            PlasmaComponents.ToolTip { visible: configuredHover.hovered; text: root.usageHelp(badges.row.modelData) }
        }
        Components.Pill {
            visible: badges.row.used === 0 && badges.row.configured === 0
            dense: true
            tone: "muted"
            text: i18n("Unused")
        }
        Components.Pill {
            visible: badges.row.used < 0
            dense: true
            tone: "warn"
            text: i18n("Usage unknown")
            HoverHandler { id: unknownHover }
            PlasmaComponents.ToolTip { visible: unknownHover.hovered; text: root.usageHelp(badges.row.modelData) }
        }
        }

    /* One summary figure; Unused also toggles the filter. */
    component Figure: Components.Card {
        id: figure
        property string glyph: ""
        property string iconTone: "muted"
        property string value: ""
        property string caption: ""
        property bool clickable: false
        property bool active: false
        signal clicked()
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.minimumWidth: 0
        padding: Kirigami.Units.smallSpacing * 1.5
        interactive: clickable
        hovered: figureHover.hovered
        selected: active
        HoverHandler { id: figureHover; enabled: figure.clickable; cursorShape: Qt.PointingHandCursor }
        TapHandler { enabled: figure.clickable; onTapped: figure.clicked() }
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing * 1.5
            Components.ActionIcon {
                glyph: figure.glyph
                color: figure.toneColor(figure.iconTone)
                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                implicitHeight: implicitWidth
            }
            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true
                PlasmaComponents.Label { text: figure.value; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                PlasmaComponents.Label { text: figure.caption; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor; elide: Text.ElideRight; Layout.fillWidth: true }
            }
        }
    }

    onTabChanged: {
        root.searchText = ""
        if (root.kind === "networks" && root.sortMode === "largest") root.sortMode = "name"
        if (root.relatedItem) root.closeRelated()
        root.reload(false)
    }
    Component.onCompleted: root.reload(false)

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Components.PageHeader {
            compact: root.embedded
            title: i18n("Resources")
            subtitle: i18n("Images, volumes and networks on %1", root.backend.engineName)
        }

        // ---- tabs and the page's actions ------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: [{label: i18n("Images"), glyph: "layers", kind: "images"},
                        {label: i18n("Volumes"), glyph: "database", kind: "volumes"},
                        {label: i18n("Networks"), glyph: "network", kind: "networks"}]
                delegate: Components.SectionTabButton {
                    required property int index
                    required property var modelData
                    readonly property int count: (root.backend.resourceLists[modelData.kind] || []).length
                    text: count > 0 && !root.narrow ? i18n("%1 · %2", modelData.label, count) : modelData.label
                    checkable: true
                    checked: root.tab === index
                    onClicked: root.tab = index
                }
            }

            Item { Layout.fillWidth: true }

            PlasmaComponents.BusyIndicator {
                visible: root.loading
                running: visible
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: implicitWidth
            }
            Components.DockButton {
                id: refreshButton
                glyph: "view-refresh"
                text: i18n("Refresh")
                iconOnly: root.width < Kirigami.Units.gridUnit * 34
                onClicked: { root.reload(true); if (root.backend.diskUsageKnown) root.backend.refreshDiskUsage() }
            }
            Components.DockButton {
                id: pruneButton
                // Also under Maintain; a tray-sized popup keeps the row to what fits.
                visible: !root.narrow
                glyph: "broom"
                text: i18n("Clean Up…")
                iconOnly: root.width < Kirigami.Units.gridUnit * 34
                enabled: !root.backend.readOnly && !root.backend.isPodman
                onClicked: root.dialogs.confirmPrune()
            }
            Components.DockButton {
                variant: "primary"
                glyph: root.kind === "images" ? "download" : "list-add"
                text: root.createLabel
                iconOnly: root.width < Kirigami.Units.gridUnit * 26
                enabled: root.backend.engineActive && !root.backend.readOnly
                onClicked: root.createForCurrentTab()
            }
        }

        // ---- what this tab holds, at a glance ------------------------------
        GridLayout {
            columns: root.narrow ? 2 : 4
            columnSpacing: Kirigami.Units.smallSpacing
            rowSpacing: Kirigami.Units.smallSpacing
            uniformCellWidths: true
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            visible: !root.relatedItem

            Figure {
                glyph: root.kindGlyph; iconTone: "blue"
                value: String(root.summary.total)
                caption: root.tab === 0 ? i18n("images") : root.tab === 1 ? i18n("volumes") : i18n("networks")
            }
            Figure {
                glyph: "box"; iconTone: "ok"
                value: String(root.summary.used)
                caption: i18n("in use")
            }
            Figure {
                glyph: "circle-dashed"; iconTone: "amber"
                value: String(root.summary.unused)
                caption: root.unusedOnly ? i18n("unused · shown alone") : i18n("unused · click to filter")
                clickable: true
                active: root.unusedOnly
                onClicked: root.unusedOnly = !root.unusedOnly
            }
            Figure {
                visible: root.kind !== "networks"
                glyph: "hard-drive"; iconTone: "violet"
                value: root.diskLine ? root.diskLine.size : root.formatBytes(root.summary.bytes)
                caption: root.diskLine && root.diskLine.reclaimable
                    ? i18n("%1 reclaimable", root.diskLine.reclaimable)
                    : (root.backend.diskUsageKnown ? i18n("on disk") : i18n("click to measure reclaimable space"))
                clickable: !root.backend.diskUsageKnown
                onClicked: root.backend.refreshDiskUsage()
            }
        }

        // ---- search, sort and filter ---------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing
            visible: !root.relatedItem

            PlasmaExtras.SearchField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: root.tab === 0 ? i18n("Search images…") : root.tab === 1 ? i18n("Search volumes…") : i18n("Search networks…")
                text: root.searchText
                onTextChanged: if (root.searchText !== text) root.searchText = text
                Keys.onEscapePressed: clear()
            }
            Components.SizedComboBox {
                id: sortBox
                preferredTextWidth: Kirigami.Units.gridUnit * (root.narrow ? 6 : 8)
                model: root.sortOptions
                textRole: "label"
                valueRole: "key"
                currentIndex: Math.max(0, root.sortOptions.findIndex(function (option) { return option.key === root.sortMode }))
                onActivated: function (index) { root.sortMode = root.sortOptions[index].key }
                PlasmaComponents.ToolTip { text: i18n("Sort") }
            }
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            visible: root.kind === "volumes" && !root.relatedItem
            text: i18n("Volumes live inside Docker’s data directory. Use a bind mount when files should sit in a folder you choose.")
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            visible: root.resourceError !== "" && root.sourceItems.length > 0 && !root.relatedItem
            type: Kirigami.MessageType.Warning
            text: i18n("Refresh failed: %1. Showing the last successful results.", root.resourceError)
        }

        // ---- the list --------------------------------------------------------
        PlasmaComponents.ScrollView {
            PlasmaComponents.ScrollBar.vertical.policy: PlasmaComponents.ScrollBar.AlwaysOn
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.relatedItem
            background: null
            contentItem: ListView {
                id: tableView
                model: root.items
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                reuseItems: true
                spacing: Kirigami.Units.smallSpacing
                topMargin: 1
                bottomMargin: Kirigami.Units.smallSpacing

                delegate: Item {
                    id: resourceRow
                    required property var modelData
                    readonly property int used: root.usageCount(modelData)
                    readonly property int configured: root.configuredImageCount(modelData)
                    readonly property bool hasContainers: root.knownContainers(modelData).length > 0
                    width: ListView.view.width - Kirigami.Units.smallSpacing * 2
                    x: Kirigami.Units.smallSpacing
                    height: rowCard.implicitHeight

                    Components.Card {
                        id: rowCard
                        anchors.left: parent.left
                        anchors.right: parent.right
                        padding: Kirigami.Units.smallSpacing * 1.5
                        interactive: true
                        hovered: rowHover.hovered
                        HoverHandler { id: rowHover }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.largeSpacing

                            Components.ActionIcon {
                                glyph: root.kindGlyph
                                color: resourceRow.used > 0 ? Kirigami.Theme.positiveTextColor
                                    : resourceRow.configured > 0 ? Style.HUE.amber : Kirigami.Theme.disabledTextColor
                                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                                implicitHeight: implicitWidth
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 0
                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    text: root.kind === "images" ? (resourceRow.modelData.repository || i18n("untagged image")) : resourceRow.modelData.name
                                    font.bold: true
                                    elide: Text.ElideMiddle
                                    PlasmaComponents.ToolTip { text: root.resourceTitle(resourceRow.modelData) }
                                }
                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    text: (root.kind === "images"
                                        ? [resourceRow.modelData.tag ? ":" + resourceRow.modelData.tag : "", resourceRow.modelData.created]
                                        : [resourceRow.modelData.driver, resourceRow.modelData.scope]).filter(function (v) { return !!v }).join("  ·  ")
                                    font: Kirigami.Theme.smallFont
                                    color: Kirigami.Theme.disabledTextColor
                                    elide: Text.ElideRight
                                }
    UsageBadges {
                                    visible: root.narrow
                                    Layout.fillWidth: true
                                    Layout.topMargin: 2
                                    row: resourceRow
                                }
                            }
                            PlasmaComponents.Label {
                                visible: root.kind !== "networks"
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                                horizontalAlignment: Text.AlignRight
                                text: resourceRow.modelData.size || "—"
                                font.features: ({"tnum": 1})
                            }
                            UsageBadges {
                                visible: !root.narrow
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 9
                                row: resourceRow
                            }
                            Components.ActionToolButton {
                                id: moreButton
                                glyph: "application-menu"
                                text: i18n("More actions")
                                onClicked: root.openItemMenu(resourceRow.modelData, moreButton)
                            }
                            Components.ActionToolButton {
                                id: removeButton
                                objectName: "resourceRemoveButton"
                                glyph: "trash"
                                text: i18n("Remove")
                                enabled: root.canRemove(resourceRow.modelData)
                                opacity: enabled ? 1 : 0.35
                                onClicked: root.requestRemove(resourceRow.modelData)
                                PlasmaComponents.ToolTip { text: root.removeHelp(resourceRow.modelData) }
                            }
                        }
                    }
                }

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - Kirigami.Units.gridUnit * 2, Kirigami.Units.gridUnit * 28)
                    visible: tableView.count === 0 && !root.loading
                        && (root.resourceError === "" || root.sourceItems.length > 0)
                    text: root.searchText !== "" ? i18n("No resources match this search.")
                        : (root.unusedOnly ? i18n("No unused resources.")
                        : (root.kind === "images" ? i18n("No images yet")
                        : (root.kind === "volumes" ? i18n("No Docker volumes yet") : i18n("No networks found"))))
                    icon.name: "folder-open"
                    helpfulAction: Kirigami.Action {
                        text: root.searchText === "" && !root.unusedOnly && root.kind !== "networks" ? root.createLabel : i18n("Refresh")
                        onTriggered: root.searchText === "" && !root.unusedOnly && root.kind !== "networks" ? root.createForCurrentTab() : root.reload()
                    }
                }

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - Kirigami.Units.gridUnit * 2, Kirigami.Units.gridUnit * 28)
                    visible: tableView.count === 0 && !root.loading && root.resourceError !== ""
                        && root.sourceItems.length === 0
                    text: i18n("Could not load %1: %2", root.kind, root.resourceError)
                    icon.name: "dialog-error"
                    helpfulAction: Kirigami.Action { text: i18n("Retry"); onTriggered: root.reload() }
                }

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    visible: tableView.count === 0 && root.loading
                    text: i18n("Loading %1…", root.kind)
                    icon.name: "view-refresh"
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Kirigami.Units.largeSpacing
            visible: !!root.relatedItem
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                Components.ActionToolButton { glyph: "go-previous"; text: i18n("Back to %1", root.kind); onClicked: root.closeRelated() }
                PlasmaExtras.Heading { Layout.fillWidth: true; level: 3; elide: Text.ElideMiddle; text: root.infoTitle !== "" ? root.infoTitle : i18n("References for %1", root.resourceTitle(root.relatedItem || ({}))) }
            }
            Components.LogViewer {
                visible: root.infoTitle !== ""
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: root.infoText
                emptyText: i18n("No output.")
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: root.infoTitle === "" && root.relatedRecords.length === 0 && root.relatedConfiguredRecords.length === 0
                wrapMode: Text.Wrap
                text: root.usageCount(root.relatedItem || ({})) > 0
                    ? i18n("Docker reports this resource is in use, but its containers are not in the current container list.")
                    : i18n("Usage is unknown. Refresh the containers and this resource before removal.")
                color: Kirigami.Theme.neutralTextColor
            }
            PlasmaComponents.Label {
                visible: root.relatedConfiguredRecords.length > 0
                Layout.fillWidth: true
                text: i18n("Configured Compose services · %1", root.relatedConfiguredRecords.length)
                font.bold: true
                color: Kirigami.Theme.neutralTextColor
            }
            ListView {
                visible: root.relatedConfiguredRecords.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, Kirigami.Units.gridUnit * 10)
                clip: true
                model: root.relatedConfiguredRecords
                delegate: PlasmaComponents.ItemDelegate {
                    required property var modelData
                    width: ListView.view.width
                    text: modelData.name
                    onClicked: root.openDetail(modelData.id)
                    contentItem: RowLayout {
                        Components.StateDot { containerState: modelData.state; health: modelData.health }
                        ColumnLayout {
                            Layout.fillWidth: true
                            PlasmaComponents.Label { text: modelData.name; font.bold: true; elide: Text.ElideRight }
                            PlasmaComponents.Label { text: i18n("Configured · %1", modelData.image); font: Kirigami.Theme.smallFont; opacity: 0.7; elide: Text.ElideMiddle }
                        }
                        PlasmaComponents.Label { text: i18n("Open details"); color: Kirigami.Theme.linkColor }
                    }
                }
            }
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.relatedRecords
                header: RowLayout {
                    width: parent.width
                    visible: root.relatedRecords.length > 0
                    Components.ActionIcon { glyph: "package"; color: Kirigami.Theme.linkColor }
                    PlasmaComponents.Label { text: i18np("Existing containers · %1", "Existing containers · %1", root.relatedRecords.length); font.bold: true; color: Kirigami.Theme.linkColor }
                }
                delegate: PlasmaComponents.ItemDelegate {
                    required property var modelData
                    width: ListView.view.width
                    text: modelData.name
                    onClicked: root.openDetail(modelData.id)
                    contentItem: RowLayout {
                        Components.StateDot { containerState: modelData.state; health: modelData.health }
                        ColumnLayout {
                            Layout.fillWidth: true
                            PlasmaComponents.Label { text: modelData.name; font.bold: true; elide: Text.ElideRight }
                            PlasmaComponents.Label { text: modelData.image; font: Kirigami.Theme.smallFont; opacity: 0.7; elide: Text.ElideMiddle }
                        }
                        PlasmaComponents.Label { text: modelData.status; font: Kirigami.Theme.smallFont; opacity: 0.7 }
                        PlasmaComponents.Label { text: i18n("Open details"); color: Kirigami.Theme.linkColor }
                    }
                }
            }
        }
    }

    // ---- per-item actions -----------------------------------------------------
    component MenuEntry: Components.ActionMenuDelegate {
        property string glyph: ""
        icon.source: glyph !== "" ? Qt.resolvedUrl(ActionIcons.path(glyph)) : ""
    }
    PlasmaComponents.Menu {
        id: itemMenu
        // Plasma's default delegate reads parent.width before it has a parent.
        delegate: Components.ActionMenuDelegate { width: parent ? parent.width : implicitWidth }
        readonly property var item: root.menuItem || ({})
        readonly property bool writable: !root.backend.readOnly && root.backend.engineActive
        MenuEntry { visible: root.kind === "images" && itemMenu.writable; text: i18n("Deploy from This Image…"); glyph: "package-plus"
            onTriggered: root.deploymentRequested(1, itemMenu.item.ref || "") }
        MenuEntry { visible: root.kind === "images" && itemMenu.writable && !!itemMenu.item.repository && itemMenu.item.repository !== "<none>"; text: i18n("Pull Latest"); glyph: "system-download"
            onTriggered: root.backend.pullImageRef(itemMenu.item.ref) }
        MenuEntry { visible: root.usageCount(itemMenu.item) > 0 || root.configuredImageCount(itemMenu.item) > 0; text: i18n("Show Containers"); glyph: "box"
            onTriggered: root.openRelated(itemMenu.item) }
        PlasmaComponents.MenuSeparator {}
        MenuEntry { text: i18n("Inspect"); glyph: "document-properties"; onTriggered: root.openInfo(itemMenu.item, "inspect") }
        MenuEntry { visible: root.kind === "images"; text: i18n("Layer History"); glyph: "layers"; onTriggered: root.openInfo(itemMenu.item, "history") }
        PlasmaComponents.Menu {
            id: connectMenu
            title: i18n("Connect a Container")
            enabled: root.kind === "networks" && itemMenu.writable && !itemMenu.item.builtin
            Instantiator {
                model: root.kind === "networks" && itemMenu.opened ? root.networkMembers(itemMenu.item, false) : []
                delegate: MenuEntry { required property var modelData; text: modelData.name; glyph: "plug"; onTriggered: root.backend.networkConnect(itemMenu.item, modelData, true) }
                onObjectAdded: function (index, object) { connectMenu.insertItem(index, object) }
                onObjectRemoved: function (index, object) { connectMenu.removeItem(object) }
            }
        }
        PlasmaComponents.Menu {
            id: disconnectMenu
            title: i18n("Disconnect a Container")
            enabled: root.kind === "networks" && itemMenu.writable && !itemMenu.item.builtin
            Instantiator {
                model: root.kind === "networks" && itemMenu.opened ? root.networkMembers(itemMenu.item, true) : []
                delegate: MenuEntry { required property var modelData; text: modelData.name; glyph: "unplug"; onTriggered: root.backend.networkConnect(itemMenu.item, modelData, false) }
                onObjectAdded: function (index, object) { disconnectMenu.insertItem(index, object) }
                onObjectRemoved: function (index, object) { disconnectMenu.removeItem(object) }
            }
        }
        PlasmaComponents.MenuSeparator {}
        MenuEntry { text: root.kind === "images" ? i18n("Copy Reference") : i18n("Copy Name"); glyph: "edit-copy"
            onTriggered: clipboard.content = root.kind === "images" ? (itemMenu.item.ref || itemMenu.item.id) : itemMenu.item.name }
        MenuEntry { text: i18n("Remove…"); glyph: "trash"; enabled: root.canRemove(itemMenu.item); onTriggered: root.requestRemove(itemMenu.item) }
    }
    KQuickControlsAddons.Clipboard { id: clipboard }
}
