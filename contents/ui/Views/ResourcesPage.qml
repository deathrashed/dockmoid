pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

import "../components" as Components
import "../../lib/style.js" as Style

/* Images, Docker volumes and networks, including verified usage and cleanup. */
Item {
    id: root

    required property var backend
    /* True when shown inside the main page's dock. */
    property bool embedded: false
    required property var dialogs
    required property var navigator

    signal openDetail(string recordId)
    signal deploymentRequested(int initialTab)

    property int tab: 0 // images, volumes, networks
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
    readonly property int tableWidth: root.kind === "images" ? 900 : root.kind === "volumes" ? 730 : 760

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

    function closeRelated() {
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

    function createForCurrentTab() { root.deploymentRequested(root.tab === 0 ? 0 : 3) }

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
            tone: "teal"; glyph: "boxes"
            subtitle: i18n("Images, volumes and networks on %1", root.backend.engineName)
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: [i18n("Images"), i18n("Volumes"), i18n("Networks")]
                delegate: Components.SectionTabButton {
                    required property int index
                    required property string modelData
                    id: resourceTab
                    text: modelData
                    checkable: true
                    checked: root.tab === index
                    onClicked: root.tab = index
                }
            }

            Item { Layout.fillWidth: true }

            Components.ActionToolButton {
                glyph: "list-add"
                text: root.tab === 0 ? i18n("Add image or container…") : i18n("Create resource…")
                enabled: root.backend.engineActive && !root.backend.readOnly
                onClicked: root.createForCurrentTab()
            }

            PlasmaComponents.BusyIndicator {
                visible: root.loading
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: implicitWidth
            }

            Components.ActionToolButton {
                id: refreshButton
                glyph: "view-refresh"
                text: i18n("Refresh resources")
                onClicked: root.reload()
            }

            Components.ActionToolButton {
                id: diskRefreshButton
                glyph: "drive-harddisk"
                text: i18n("Refresh disk usage")
                onClicked: root.backend.refreshDiskUsage()
            }

            Components.ActionToolButton {
                id: pruneButton
                glyph: "edit-clear-history"
                text: i18n("Review cleanup…")
                enabled: !root.backend.readOnly && !root.backend.isPodman
                onClicked: root.dialogs.confirmPrune()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaExtras.SearchField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: i18n("Search resources")
                text: root.searchText
                onTextChanged: if (root.searchText !== text) root.searchText = text
                Keys.onEscapePressed: clear()
            }

            PlasmaComponents.ComboBox {
                id: sortBox
                Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                model: root.sortOptions
                textRole: "label"
                valueRole: "key"
                currentIndex: Math.max(0, root.sortOptions.findIndex(function (option) { return option.key === root.sortMode }))
                onActivated: function (index) { root.sortMode = root.sortOptions[index].key }
                PlasmaComponents.ToolTip { text: i18n("Sort resources") }
            }

            PlasmaComponents.CheckBox {
                text: i18n("Unused")
                checked: root.unusedOnly
                onToggled: root.unusedOnly = checked
                PlasmaComponents.ToolTip { text: i18n("Only show resources with verified zero usage.") }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing
            PlasmaComponents.Label {
                text: i18n("Disk usage")
                font.bold: true
            }
            PlasmaComponents.Label {
                visible: !root.backend.diskUsageKnown
                text: i18n("Not loaded")
                color: Kirigami.Theme.disabledTextColor
            }
            Flow {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                Repeater {
                    model: root.backend.diskUsage || []
                    delegate: PlasmaComponents.Label {
                        required property var modelData
                        text: i18n("%1: %2 · %3 reclaimable", modelData.type,
                                   modelData.size || i18n("unknown"), modelData.reclaimable || i18n("unknown"))
                        font: Kirigami.Theme.smallFont
                        PlasmaComponents.ToolTip { text: i18n("%1 total · %2 of %3 active", modelData.total, modelData.active, modelData.total) }
                    }
                }
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            visible: root.kind === "volumes"
            type: Kirigami.MessageType.Information
            text: i18n("Docker volumes are managed inside Docker’s data directory. Use a bind mount when you want files in a chosen host folder.")
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            visible: root.resourceError !== "" && root.sourceItems.length > 0 && !root.relatedItem
            type: Kirigami.MessageType.Warning
            text: i18n("Refresh failed: %1. Showing the last successful results.", root.resourceError)
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.border)
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.relatedItem
            spacing: 0

            PlasmaComponents.ScrollView {
        PlasmaComponents.ScrollBar.vertical.policy: PlasmaComponents.ScrollBar.AlwaysOn
                Layout.fillWidth: true
                Layout.fillHeight: true
                background: null
                contentItem: ListView {
                    id: tableView
                    width: Math.max(root.tableWidth, parent ? parent.width : root.tableWidth)
                    height: parent ? parent.height : 0
                    model: root.items
                    contentWidth: width
                    flickableDirection: Flickable.HorizontalAndVerticalFlick
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    reuseItems: true

                    header: ColumnLayout {
                        width: tableView.width
                        spacing: 0
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: Kirigami.Units.gridUnit * 2; color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface2)
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Kirigami.Units.smallSpacing
                                anchors.rightMargin: Kirigami.Units.smallSpacing
                                spacing: Kirigami.Units.smallSpacing
                                PlasmaComponents.Label { Layout.preferredWidth: root.kind === "images" ? 250 : 235; text: root.kind === "images" ? i18n("Image") : i18n("Name"); font.bold: true }
                                PlasmaComponents.Label { Layout.preferredWidth: root.kind === "images" ? 130 : 120; text: root.kind === "images" ? i18n("Tag") : i18n("Driver"); font.bold: true }
                                PlasmaComponents.Label { Layout.preferredWidth: root.kind === "images" ? 105 : 105; visible: root.kind !== "networks"; text: i18n("Size"); font.bold: true }
                                PlasmaComponents.Label { Layout.preferredWidth: root.kind === "images" ? 140 : 115; visible: root.kind === "images"; text: i18n("Created"); font.bold: true }
                                PlasmaComponents.Label { Layout.preferredWidth: root.kind === "networks" ? 100 : 145; visible: root.kind === "networks"; text: i18n("Scope"); font.bold: true }
                                PlasmaComponents.Label { Layout.preferredWidth: 160; text: i18n("Used by"); font.bold: true }
                                Item { Layout.fillWidth: true }
                                Item { Layout.preferredWidth: Kirigami.Units.iconSizes.small }
                            }
                        }
                    }

                    delegate: Item {
                        id: resourceRow
                        required property var modelData
                        width: tableView.width
                        height: rowLayout.implicitHeight + Kirigami.Units.smallSpacing
                        RowLayout {
                            id: rowLayout
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.leftMargin: Kirigami.Units.smallSpacing
                            anchors.rightMargin: Kirigami.Units.smallSpacing
                            anchors.topMargin: Kirigami.Units.smallSpacing / 2
                            spacing: Kirigami.Units.smallSpacing

                            PlasmaComponents.Label {
                                Layout.preferredWidth: root.kind === "images" ? 250 : 235
                                text: root.kind === "images" ? (resourceRow.modelData.repository || i18n("untagged image")) : resourceRow.modelData.name
                                elide: Text.ElideMiddle
                                PlasmaComponents.ToolTip { text: root.kind === "images" ? resourceRow.modelData.repository : resourceRow.modelData.name }
                            }
                            PlasmaComponents.Label {
                                Layout.preferredWidth: root.kind === "images" ? 130 : 120
                                text: root.kind === "images" ? (resourceRow.modelData.tag || "—") : resourceRow.modelData.driver
                                elide: Text.ElideRight
                                PlasmaComponents.ToolTip { text: root.kind === "images" ? resourceRow.modelData.tag : resourceRow.modelData.driver }
                            }
                            PlasmaComponents.Label {
                                Layout.preferredWidth: 105
                                visible: root.kind !== "networks"
                                text: resourceRow.modelData.size || "—"
                                elide: Text.ElideRight
                            }
                            PlasmaComponents.Label {
                                Layout.preferredWidth: 140
                                visible: root.kind === "images"
                                text: resourceRow.modelData.created || "—"
                                elide: Text.ElideRight
                            }
                            PlasmaComponents.Label {
                                Layout.preferredWidth: 115
                                visible: root.kind === "networks"
                                text: resourceRow.modelData.scope || "—"
                            }
                            RowLayout {
                                Layout.preferredWidth: 160
                                spacing: 1
                                PlasmaComponents.Label {
                                    visible: root.usageCount(resourceRow.modelData) === 0
                                    text: root.usageRowText(resourceRow.modelData)
                                    color: root.configuredImageCount(resourceRow.modelData) > 0
                                        ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.positiveTextColor
                                    font: Kirigami.Theme.smallFont
                                }
                                ColumnLayout {
                                    Layout.preferredWidth: 160
                                    spacing: 1
                                    PlasmaComponents.Button {
                                        id: existingUsageButton
                                        visible: root.usageCount(resourceRow.modelData) > 0
                                        Layout.fillWidth: true
                                        implicitHeight: Kirigami.Units.gridUnit * 1.5
                                        text: i18n("Existing · %1", i18np("%1 container", "%1 containers", root.usageCount(resourceRow.modelData)))
                                        enabled: root.knownContainers(resourceRow.modelData).length > 0
                                        onClicked: root.openRelated(resourceRow.modelData)
                                        background: Rectangle {
                                            radius: Kirigami.Units.smallSpacing
                                            color: Qt.alpha(Kirigami.Theme.linkColor, Style.ALPHA.tintWeak)
                                            border.width: 1
                                            border.color: Qt.alpha(Kirigami.Theme.linkColor, Style.ALPHA.borderAccent)
                                        }
                                        contentItem: RowLayout {
                                            spacing: Kirigami.Units.smallSpacing / 2
                                            Components.ActionIcon { glyph: "package"; color: existingUsageButton.enabled ? Kirigami.Theme.linkColor : Kirigami.Theme.disabledTextColor; implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: implicitWidth }
                                            PlasmaComponents.Label { Layout.fillWidth: true; text: existingUsageButton.text; color: existingUsageButton.enabled ? Kirigami.Theme.linkColor : Kirigami.Theme.disabledTextColor; font: Kirigami.Theme.smallFont; elide: Text.ElideRight }
                                        }
                                        PlasmaComponents.ToolTip { text: root.usageHelp(resourceRow.modelData) }
                                    }
                                    PlasmaComponents.Button {
                                        id: configuredUsageButton
                                        visible: root.configuredImageCount(resourceRow.modelData) > 0
                                        Layout.fillWidth: true
                                        implicitHeight: Kirigami.Units.gridUnit * 1.5
                                        text: i18n("Configured · %1", i18np("%1 Compose service", "%1 Compose services", root.configuredImageCount(resourceRow.modelData)))
                                        onClicked: root.openRelated(resourceRow.modelData)
                                        background: Rectangle {
                                            radius: Kirigami.Units.smallSpacing
                                            color: Qt.alpha(Kirigami.Theme.neutralTextColor, Style.ALPHA.tintWeak)
                                            border.width: 1
                                            border.color: Qt.alpha(Kirigami.Theme.neutralTextColor, Style.ALPHA.borderAccent)
                                        }
                                        contentItem: RowLayout {
                                            spacing: Kirigami.Units.smallSpacing / 2
                                            Components.ActionIcon { glyph: "copy-compose"; color: Kirigami.Theme.neutralTextColor; implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: implicitWidth }
                                            PlasmaComponents.Label { Layout.fillWidth: true; text: configuredUsageButton.text; color: Kirigami.Theme.neutralTextColor; font: Kirigami.Theme.smallFont; elide: Text.ElideRight }
                                        }
                                        PlasmaComponents.ToolTip { text: root.usageHelp(resourceRow.modelData) }
                                    }
                                }
                                PlasmaComponents.Label {
                                    visible: root.usageCount(resourceRow.modelData) < 0
                                    text: root.usageText(resourceRow.modelData)
                                    color: Kirigami.Theme.neutralTextColor
                                    font: Kirigami.Theme.smallFont
                                    PlasmaComponents.ToolTip { text: root.usageHelp(resourceRow.modelData) }
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Components.ActionToolButton {
                                id: removeButton
                                objectName: "resourceRemoveButton"
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                glyph: "edit-delete"
                                text: i18n("Remove")
                                enabled: root.canRemove(resourceRow.modelData)
                                onClicked: root.requestRemove(resourceRow.modelData)
                                PlasmaComponents.ToolTip { text: root.removeHelp(resourceRow.modelData) }
                            }
                        }
                        Kirigami.Separator { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; opacity: 0.35 }
                    }

                    Kirigami.PlaceholderMessage {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - Kirigami.Units.gridUnit * 2, Kirigami.Units.gridUnit * 28)
                        visible: tableView.count === 0 && !root.loading
                            && (root.resourceError === "" || root.sourceItems.length > 0)
                        text: root.searchText !== "" ? i18n("No resources match this search.")
                            : (root.unusedOnly ? i18n("No resources have verified zero usage.")
                            : (root.kind === "images" ? i18n("No images found")
                            : (root.kind === "volumes" ? i18n("No Docker volumes found") : i18n("No networks found"))))
                        icon.name: "folder-open"
                        helpfulAction: Kirigami.Action {
                            text: root.kind === "volumes" && root.searchText === "" && !root.unusedOnly
                                ? i18n("Create volume") : i18n("Refresh")
                            onTriggered: root.kind === "volumes" && root.searchText === "" && !root.unusedOnly
                                ? root.deploymentRequested(3) : root.reload()
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
                PlasmaExtras.Heading { Layout.fillWidth: true; level: 3; text: i18n("References for %1", root.resourceTitle(root.relatedItem || ({}))) }
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: root.relatedRecords.length === 0 && root.relatedConfiguredRecords.length === 0
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
}
