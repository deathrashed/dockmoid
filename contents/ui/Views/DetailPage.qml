pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../components" as Components
import "../../lib/parsers.js" as Parsers
import "../../lib/status.js" as Status
import "../../lib/style.js" as Style

/*
 * DetailPage — everything known about one container, plus its logs.
 *
 * The record is re-resolved from the backend on every refresh (through the
 * `revision` counter) rather than captured when the page was pushed, so the
 * page keeps showing live CPU, memory and state while it stays open.
 *
 * The three tabs are a plain segmented row of tool buttons rather than a TabBar
 * because there are only three, and a tab widget would spend more width on its
 * chrome than on content.
 */
Item {
    id: root

    required property var backend
    required property var dialogs
    required property var navigator
    required property string recordId

    /* Re-evaluated whenever the backend bumps its revision counter. */
    property int pageGeneration: -1
    readonly property var record: {
        return pageGeneration === backend.generation && backend.revision >= 0
            ? backend.findRecord(recordId) : null
    }

    readonly property var cfg: plasmoid.configuration
    readonly property var links: backend.linksFor(record)
    readonly property bool hasRecord: record !== null
    readonly property bool isNotCreated: root.hasRecord && root.record.state === "not-created"

    property int tab: 0        // 0 overview, 1 logs, 2 inspect, 3 run
    property string runText: ""
    property bool runBusy: false
    property string logsRequestId: ""
    property string inspectRequestId: ""
    property int logsSequence: 0
    property int inspectSequence: 0

    Component.onCompleted: {
        pageGeneration = backend.generation
        if (!root.isNotCreated) {
            logsRequestId = backend.newOutputRequest("logs", recordId)
            inspectRequestId = backend.newOutputRequest("inspect", recordId)
        }
    }

    function runCommand(command) {
        if (!root.hasRecord || command.trim() === "") return
        root.runBusy = true
        root.runText = "$ " + command + "\n"
        root.backend.execOnce(root.record, command, function (code, output) {
            root.runText += output + (code !== 0 ? "\n[" + i18n("exit code %1", code) + "]" : "")
            root.runBusy = false
        })
    }
    property string logsText: ""
    property string inspectText: ""

    /* Raised by the overflow menu; PopupView connects this to its own
       showOutput() so the page does not need a reference to the stack. */
    signal outputRequested(string title, string content, bool live, string recordId,
                           string kind, string requestId, int contextGeneration)

    function refreshLogs() {
        if (!root.hasRecord || root.isNotCreated || root.pageGeneration !== root.backend.generation) return
        root.backend.fetchLogs(root.record, root.cfg.logTailLines, logsRequestId, pageGeneration)
    }

    function refreshInspect() {
        if (!root.hasRecord || root.isNotCreated || root.pageGeneration !== root.backend.generation) return
        root.backend.fetchInspect(root.record, inspectRequestId, pageGeneration)
    }

    onTabChanged: {
        if (root.isNotCreated && tab !== 0) { root.tab = 0; return }
        if (tab === 1) root.refreshLogs()
        if (tab === 2 && inspectText === "") root.refreshInspect()
    }

    Connections {
        target: root.backend
        function onRecordOutput(kind, id, contextGeneration, requestId, sequence, content) {
            if (id !== root.recordId || contextGeneration !== root.pageGeneration
                    || root.pageGeneration !== root.backend.generation) return
            if (kind === "logs" && requestId === root.logsRequestId && sequence > root.logsSequence) {
                root.logsSequence = sequence
                root.logsText = content
            }
            if (kind === "inspect" && requestId === root.inspectRequestId && sequence > root.inspectSequence) {
                root.inspectSequence = sequence
                root.inspectText = content
            }
        }
    }

    Timer {
        // Follow the tail while the logs tab is open. Same cadence as the
        // stats poll, so the two do not fight over the command runner.
        interval: Math.max(2, root.cfg.usageInterval) * 1000
        repeat: true
        running: root.visible && root.navigator.currentItem === root
            && root.tab === 1 && root.hasRecord && root.pageGeneration === root.backend.generation
        onTriggered: root.refreshLogs()
    }

    // =========================================================== chrome ====

    readonly property bool narrow: root.width < 560
    readonly property string attention: root.hasRecord ? Status.attentionKind(root.record) : ""
    readonly property string stateWord: {
        switch (root.attention) {
        case "failed": return i18n("Failed")
        case "unhealthy": return i18n("Unhealthy")
        case "paused": return i18n("Paused")
        case "restarting": return i18n("Restarting")
        case "not-created": return i18n("Not created")
        case "running": return i18n("Running")
        default: return i18n("Stopped")
        }
    }
    readonly property var badgeInfo: Status.badgeSpec(root.attention)
    readonly property string stateTone: root.attention === "not-created" ? "cyan"
        : root.attention === "stopped" ? "slate"
        : Status.glyphTone(root.attention, root.hasRecord && root.record.isRunning === true)

    Components.Tones { id: tones }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // -------------------------------------------------- header -------
        Components.PageHeader {
            title: root.hasRecord ? root.record.name : i18n("Container is gone")
            subtitle: root.hasRecord ? String(root.record.image || "").replace(/@sha256:([0-9a-f]{12})[0-9a-f]+/i, "@sha256:$1…") : ""
            leading: Components.ServiceIcon {
                visible: root.hasRecord
                backend: root.backend
                record: root.record || ({})
                iconSize: Kirigami.Units.iconSizes.medium
                tile: true
            }
            badges: [
                Components.Pill {
                    visible: root.hasRecord
                    text: root.stateWord
                    tone: root.badgeInfo.tone
                    variant: root.badgeInfo.variant
                    glyph: root.badgeInfo.glyph
                    statusDot: root.badgeInfo.dot
                    pulse: root.badgeInfo.dot
                },
                Components.Pill {
                    visible: root.hasRecord && root.record.isRunning === true && root.record.health !== "" && root.record.health !== "none"
                    label: i18n("health")
                    text: root.record.health
                    tone: root.record.health === "healthy" ? "ok" : root.record.health === "unhealthy" ? "bad" : "amber"
                },
                Components.Pill {
                    visible: root.hasRecord && root.record.updateAvailable === true
                    text: i18n("Update available")
                    tone: "violet"
                    glyph: "cloud-download"
                }
            ]

            Components.DockButton {
                visible: root.hasRecord && actions.canPerform("start-stop")
                variant: root.record && root.record.isRunning ? "default" : "primary"
                iconOnly: root.narrow
                glyph: root.record && root.record.isRunning ? "media-playback-stop" : "media-playback-start"
                text: root.isNotCreated ? i18n("Create and start") : (root.record && root.record.isRunning ? i18n("Stop") : i18n("Start"))
                onClicked: actions.perform("start-stop")
            }
            Components.DockButton {
                visible: root.hasRecord && !root.isNotCreated && actions.canPerform("restart")
                iconOnly: root.narrow
                glyph: "view-refresh"
                text: i18n("Restart")
                onClicked: actions.perform("restart")
            }
            Components.DockButton {
                visible: root.hasRecord && !root.isNotCreated
                iconOnly: root.narrow
                glyph: "text-x-generic"
                text: i18n("Logs")
                onClicked: root.tab = 1
            }
            Components.ActionToolButton {
                visible: root.hasRecord
                glyph: "application-menu"
                text: i18n("More actions")
                onClicked: actions.popup(this, 0, height)
            }
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.largeSpacing
            visible: !root.hasRecord
            wrapMode: Text.WordWrap
            text: i18n("This container no longer exists. Go back to see the current list.")
            color: Kirigami.Theme.negativeTextColor
        }

        // ------------------------------------------------- web links ----
        Flow {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing
            visible: root.hasRecord && root.record.isRunning && root.links.length > 0
            spacing: Kirigami.Units.smallSpacing
            Repeater {
                model: root.links
                delegate: Components.DockButton {
                    required property var modelData
                    glyph: "insert-link"
                    text: String(modelData.label || i18n("Web UI")) + " · " + String(modelData.port || "")
                    onClicked: root.backend.openLink(modelData)
                    PlasmaComponents.ToolTip { text: modelData.url || Parsers.linkUrl(modelData) }
                }
            }
        }

        Components.ContainerActions {
            id: webActions
            backend: root.backend
            record: root.record
            dialogs: root.dialogs
            browserOnly: true
        }

        Components.ContainerActions {
            id: actions
            objectName: "detailActions"
            backend: root.backend
            record: root.record
            dialogs: root.dialogs
            excludedActions: ["details", "start", "stop", "create and start", "restart", "logs", "open web ui"]
            onOpenOutput: function (title, content, live, id) {
                var request = root.backend.latestOutputRequest
                root.outputRequested(title, content, live, id,
                                     request ? request.kind : "output",
                                     request ? request.requestId : "",
                                     request ? request.generation : root.backend.generation)
            }
        }

        // --------------------------------------------------- tabs ---------
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing
            visible: root.hasRecord
            spacing: Kirigami.Units.smallSpacing

            Components.SectionTabButton {
                id: tabOverview
                text: i18n("Overview")
                checkable: true
                checked: root.tab === 0
                onClicked: root.tab = 0
            }
            Components.SectionTabButton {
                id: tabLogs
                objectName: "detailLogsTab"
                visible: !root.isNotCreated
                text: i18n("Logs")
                checkable: true
                checked: root.tab === 1
                onClicked: root.tab = 1
            }
            Components.SectionTabButton {
                id: tabInspect
                objectName: "detailInspectTab"
                visible: !root.isNotCreated
                text: i18n("Inspect")
                checkable: true
                checked: root.tab === 2
                onClicked: root.tab = 2
            }
            Components.SectionTabButton {
                id: tabRun
                objectName: "detailRunTab"
                text: i18n("Run")
                visible: root.hasRecord && !root.isNotCreated && root.record.isRunning
                checkable: true
                checked: root.tab === 3
                onClicked: root.tab = 3
            }

            Item { Layout.fillWidth: true }

            Components.ActionToolButton {
                id: logsRefresh
                visible: root.tab === 1 && !root.isNotCreated
                glyph: "view-refresh"
                text: i18n("Refresh logs")
                onClicked: root.refreshLogs()
            }
            Components.ActionToolButton {
                id: logsFollow
                visible: root.tab === 1 && !root.isNotCreated
                glyph: "utilities-terminal"
                text: i18n("Follow in terminal")
                onClicked: root.backend.followLogs(root.record)
            }
            Components.ActionToolButton {
                id: inspectRefresh
                visible: root.tab === 2 && !root.isNotCreated
                glyph: "view-refresh"
                text: i18n("Refresh inspect output")
                onClicked: root.refreshInspect()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.borderFaint)
        }

        // --------------------------------------------------- body ---------
        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.hasRecord
            sourceComponent: !root.hasRecord
                ? null
                : (root.tab === 1 ? logsComponent
                   : (root.tab === 2 ? inspectComponent
                   : (root.tab === 3 ? runComponent : overviewComponent)))
        }
    }

    // =========================================================== tabs ======

    Component {
        id: overviewComponent

        PlasmaComponents.ScrollView {
            background: null
            PlasmaComponents.ScrollBar.vertical.policy: PlasmaComponents.ScrollBar.AlwaysOn

            contentItem: Flickable {
                objectName: "detailOverviewScroll"
                contentWidth: width
                contentHeight: overviewFields.implicitHeight
                clip: true
                ColumnLayout {
                id: overviewFields
                width: parent.width
                spacing: 0

                PlasmaComponents.Label {
                    objectName: "detailNotCreatedMessage"
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.largeSpacing
                    visible: root.isNotCreated
                    wrapMode: Text.WordWrap
                    text: i18n("This Compose service is configured, but its container has not been created yet. Create and start it to inspect logs or run commands.")
                    color: Kirigami.Theme.neutralTextColor
                }

                Components.Card {
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.largeSpacing
                    Layout.bottomMargin: 0
                    padding: Kirigami.Units.smallSpacing
                    title: i18n("Overview")
                    titleGlyph: "badge-info"
                    Components.FieldRow { Layout.fillWidth: true; glyph: "activity"; label: i18n("Status"); value: root.record.status }
                    Components.FieldRow { Layout.fillWidth: true; glyph: "heart-pulse"; label: i18n("Health"); value: root.record.health !== "none" ? root.record.health : "" }
                    Components.FieldRow {
                        Layout.fillWidth: true
                        glyph: "box"
                        label: i18n("Image")
                        value: String(root.record.image || "").replace(/@sha256:([0-9a-f]{12})[0-9a-f]+/i, "@sha256:$1…")
                        copyValue: root.record.image
                        copyable: true
                        revealable: true
                        wrap: true
                    }
                    Components.FieldRow { Layout.fillWidth: true; glyph: "folder-kanban"; label: i18n("Project"); value: root.record.project }
                    Components.FieldRow { Layout.fillWidth: true; glyph: "workflow"; label: i18n("Service"); value: root.record.service }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                        Layout.topMargin: Kirigami.Units.smallSpacing
                        visible: root.record.restartPolicy !== ""
                        spacing: Kirigami.Units.smallSpacing
                        PlasmaComponents.Label { Layout.preferredWidth: Kirigami.Units.gridUnit * 6; Layout.alignment: Qt.AlignTop; text: i18n("Autostart"); color: Kirigami.Theme.disabledTextColor }
                        PlasmaComponents.ComboBox {
                            enabled: !root.backend.readOnly && !root.backend.isPodman
                            Layout.fillWidth: true
                            readonly property var policies: ["no", "on-failure", "unless-stopped", "always"]
                            model: policies.map(function (p) { return root.backend.policyLabel(p) })
                            currentIndex: Math.max(0, policies.indexOf(root.record.restartPolicy))
                            onActivated: function (index) { if (policies[index] !== root.record.restartPolicy) root.backend.setRestartPolicy(root.record, policies[index]) }
                        }
                    }
                    Components.FieldRow {
                        Layout.fillWidth: true
                        glyph: "globe"
                        label: i18n("Web page")
                        value: root.record.probe === "" ? "" : (root.record.probe === "up" ? i18n("answers (%1 ms)", root.record.probeMs) : i18n("does not answer"))
                    }
                    Components.FieldRow {
                        Layout.fillWidth: true
                        glyph: "cloud-download"
                        label: i18n("Image update")
                        value: root.record.updateAvailable ? i18n("a newer version is available") : ""
                    }
                }

                Components.Card {
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.largeSpacing
                    Layout.bottomMargin: 0
                    padding: Kirigami.Units.smallSpacing
                    visible: String(root.record.ports || "") !== "" || String(root.record.mounts || "") !== ""
                    title: i18n("Ports and storage")
                    titleGlyph: "network"
                    Components.FieldRow {
                        Layout.fillWidth: true
                        glyph: "plug"
                        label: i18n("Ports")
                        value: String(root.record.ports || "").replace(/,(?=\d{3}(?:->|\/|:))/g, "")
                        copyValue: root.record.ports
                        copyable: true
                        wrap: true
                    }
                    Components.FieldRow { Layout.fillWidth: true; glyph: "hard-drive"; label: i18n("Mounts"); value: root.record.mounts; wrap: true; copyable: true }
                }

                Components.Card {
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.largeSpacing
                    Layout.bottomMargin: 0
                    visible: root.record.isRunning
                        && ((root.record.cpu !== "" && root.record.cpu !== "unavailable")
                            || (root.record.mem !== "" && root.record.mem !== "unavailable"))
                    title: i18n("Usage")
                    titleGlyph: "gauge"
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.largeSpacing
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.record.cpu !== "" && root.record.cpu !== "unavailable"
                            PlasmaComponents.Label { text: i18n("CPU %1", root.record.cpu); font: Kirigami.Theme.smallFont }
                            Components.Sparkline {
                                Layout.fillWidth: true
                                implicitHeight: Kirigami.Units.gridUnit * 2.5
                                samples: root.backend.revision >= 0 ? root.backend.historyFor(root.record.id).cpu : []
                                color: Style.HUE.cyan
                                floor: 10
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.record.mem !== "" && root.record.mem !== "unavailable"
                            PlasmaComponents.Label { text: i18n("Memory %1", root.record.mem); font: Kirigami.Theme.smallFont }
                            Components.Sparkline {
                                Layout.fillWidth: true
                                implicitHeight: Kirigami.Units.gridUnit * 2.5
                                samples: root.backend.revision >= 0 ? root.backend.historyFor(root.record.id).mem : []
                                color: Style.HUE.fuchsia
                                floor: 10
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.smallSpacing
                    Components.DetailSection {
                        Layout.fillWidth: true
                        title: i18n("Resources")
                        expanded: false
                        Components.FieldRow { Layout.fillWidth: true; label: i18n("CPU"); value: root.record.cpu }
                        Components.FieldRow { Layout.fillWidth: true; label: i18n("Memory"); value: root.record.memU !== "" && root.record.memU !== "unavailable" ? root.record.memU + (root.record.mem !== "" && root.record.mem !== "unavailable" ? "  (" + root.record.mem + ")" : "") : "" }
                        Components.FieldRow { Layout.fillWidth: true; label: i18n("Net I/O"); value: root.record.netio }
                        Components.FieldRow { Layout.fillWidth: true; label: i18n("Block I/O"); value: root.record.blockio }
                        Components.FieldRow { Layout.fillWidth: true; label: i18n("PIDs"); value: root.record.pids }
                        Components.FieldRow { Layout.fillWidth: true; label: i18n("Size"); value: root.record.size }
                    }
                    Components.DetailSection {
                        Layout.fillWidth: true
                        title: i18n("Networking")
                        Components.FieldRow { Layout.fillWidth: true; label: i18n("Networks"); value: root.record.networks; wrap: true; copyable: true }
                    }
                    Components.DetailSection {
                        Layout.fillWidth: true
                        title: i18n("Storage")
                        Components.FieldRow { Layout.fillWidth: true; label: i18n("Volumes"); value: root.record.localVolumes; wrap: true; copyable: true }
                    }
                    Components.DetailSection {
                        Layout.fillWidth: true
                        title: i18n("Container information")
                        Components.FieldRow {
                            Layout.fillWidth: true
                            label: i18n("ID")
                            value: String(root.record.id).length > 12 ? String(root.record.id).slice(0, 12) + "…" : root.record.id
                            copyValue: root.record.id
                            copyable: true
                            revealable: true
                        }
                        Components.FieldRow { Layout.fillWidth: true; label: i18n("Command"); value: root.record.command; wrap: true; copyable: true }
                        Components.FieldRow { Layout.fillWidth: true; label: i18n("Compose file"); value: root.record.composeFiles; wrap: true; copyable: true }
                        Components.FieldRow { Layout.fillWidth: true; label: i18n("Created"); value: root.record.createdAt }
                        Components.FieldRow { Layout.fillWidth: true; label: i18n("Platform"); value: root.record.platform }
                    }
                }

                }
            }
        }
    }

    Component {
        id: logsComponent

        Components.LogViewer {
            text: root.logsText
            logMode: true
            emptyText: i18n("No log output yet.")
        }
    }

    Component {
        id: runComponent

        ColumnLayout {
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.TextField {
                    id: commandField
                    Layout.fillWidth: true
                    placeholderText: i18n("A command to run inside the container, e.g. ls /app")
                    font.family: Kirigami.Theme.fixedWidthFont.family
                    enabled: !root.runBusy
                    onAccepted: { root.runCommand(text); selectAll() }
                }

                Components.ActionButton {
                    text: i18n("Run")
                    glyph: "media-playback-start"
                    enabled: !root.runBusy && commandField.text.trim() !== ""
                    onClicked: root.runCommand(commandField.text)
                }
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                text: i18n("Not interactive: it runs once with sh -c and shows the output. For a real shell use Open in → Konsole.")
                font: Kirigami.Theme.smallFont
                opacity: 0.6
                wrapMode: Text.WordWrap
            }

            Components.LogViewer {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: root.runText
                logMode: true
                emptyText: i18n("Nothing run yet.")
            }
        }
    }

    Component {
        id: inspectComponent

        Components.InspectTree {
            text: root.inspectText
            emptyText: i18n("Loading…")
        }
    }
}
