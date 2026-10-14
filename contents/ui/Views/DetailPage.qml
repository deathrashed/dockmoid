pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../components" as Components
import "../../lib/parsers.js" as Parsers
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
    property bool actionsExpanded: false

    readonly property var stripActionKeys: {
        var keys = ["details"]
        if (root.isNotCreated) keys.push("create and start")
        else if (root.record && root.record.isRunning) keys.push("stop")
        else keys.push("start")
        if (!root.isNotCreated && actions.canPerform("restart")) keys.push("restart")
        if (!root.isNotCreated && actions.canPerform("logs")) keys.push("logs")
        if (!root.isNotCreated && actions.canPerform("inspect")) keys.push("inspect")
        if (root.record && root.record.isRunning && root.links.length > 0) keys.push("links")
        if (root.actionsExpanded) {
            if (!root.backend.readOnly) keys.push("manage")
            keys.push("customize", "open", "diagnostics", "copy")
            if (root.record && !root.backend.readOnly && root.backend.canUseCompose && root.record.project !== "") keys.push("compose")
        }
        return keys
    }

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

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // -------------------------------------------------- header -------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                objectName: "detailIdentityRow"
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Components.StateDot {
                    visible: root.hasRecord
                    containerState: root.record.state
                    health: root.cfg.showHealth ? root.record.health : "none"
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: root.hasRecord ? root.record.name : i18n("Container is gone")
                    font.bold: true
                    elide: Text.ElideRight
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
                excludedActions: root.stripActionKeys
                onOpenOutput: function (title, content, live, id) {
                    var request = root.backend.latestOutputRequest
                    root.outputRequested(title, content, live, id,
                                         request ? request.kind : "output",
                                         request ? request.requestId : "",
                                         request ? request.generation : root.backend.generation)
                }
            }
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            visible: !root.hasRecord
            wrapMode: Text.WordWrap
            text: i18n("This container no longer exists. Go back to see the current list.")
            color: Kirigami.Theme.negativeTextColor
        }

        // --------------------------------------------------- tabs ---------
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
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
            color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.border)
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
        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing
            visible: root.hasRecord
            Kirigami.Separator { Layout.fillWidth: true }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    Layout.rightMargin: Kirigami.Units.largeSpacing
                    visible: root.links.length > 0
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents.Label {
                        text: i18n("Open in browser")
                        color: Kirigami.Theme.disabledTextColor
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        Repeater {
                            model: root.links
                            delegate: Components.ActionButton {
                                required property var modelData
                                glyph: "insert-link"
                                text: String(modelData.label || i18n("Web UI")) + " · " + String(modelData.port || "")
                                onClicked: root.backend.openLink(modelData)
                                PlasmaComponents.ToolTip { text: modelData.url || Parsers.linkUrl(modelData) }
                            }
                        }
                    }
                }
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                visible: root.hasRecord

                Flow {
                    id: actionStrip
                    objectName: "detailActionStrip"
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Kirigami.Units.smallSpacing

                Components.ActionButton {
                    id: primaryButton
                    objectName: "detailPrimaryAction"
                    visible: actions.canPerform("start-stop")
                    glyph: root.record && root.record.isRunning ? "media-playback-stop" : "media-playback-start"
                    text: root.isNotCreated ? i18n("Create and start") : (root.record && root.record.isRunning ? i18n("Stop") : i18n("Start"))
                    onClicked: actions.perform("start-stop")
                }

                Components.ActionButton {
                    visible: !root.isNotCreated && actions.canPerform("restart")
                    glyph: "view-refresh"
                    text: i18n("Restart")
                    onClicked: actions.perform("restart")
                }

                Components.ActionButton {
                    visible: !root.isNotCreated && actions.canPerform("logs")
                    glyph: "text-x-generic"
                    text: i18n("Logs")
                    onClicked: actions.perform("logs")
                }

                Components.ActionButton {
                    visible: !root.isNotCreated && actions.canPerform("inspect")
                    glyph: "document-properties"
                    text: i18n("Inspect")
                    onClicked: actions.perform("inspect")
                }

                Components.ActionButton {
                    id: webButton
                    visible: root.record && root.record.isRunning && root.links.length > 0
                    glyph: "insert-link"
                    text: i18n("Web links") + "  ▾"
                    onClicked: webActions.popup(webButton, 0, webButton.height)
                }

                Components.ActionButton {
                    id: manageButton
                    visible: root.actionsExpanded && !root.backend.readOnly
                    text: i18n("Manage") + "  ▾"
                    glyph: "configure"
                    onClicked: actions.popupSection("manage", manageButton)
                }

                Components.ActionButton {
                    id: customizeButton
                    visible: root.actionsExpanded
                    text: i18n("Customize") + "  ▾"
                    glyph: "preferences-desktop-icons"
                    onClicked: actions.popupSection("customize", customizeButton)
                }

                Components.ActionButton {
                    id: openButton
                    visible: root.actionsExpanded
                    text: i18n("Open") + "  ▾"
                    glyph: "document-open"
                    onClicked: actions.popupSection("open", openButton)
                }

                Components.ActionButton {
                    id: composeButton
                    visible: root.actionsExpanded && root.record && !root.backend.readOnly
                        && root.backend.canUseCompose && root.record.project !== ""
                    text: i18n("Compose") + "  ▾"
                    glyph: "docker"
                    onClicked: actions.popupSection("compose", composeButton)
                }

                Components.ActionButton {
                    id: diagnosticsButton
                    visible: root.actionsExpanded
                    text: i18n("Diagnostics") + "  ▾"
                    glyph: "utilities-system-monitor"
                    onClicked: actions.popupSection("diagnostics", diagnosticsButton)
                }

                Components.ActionButton {
                    id: copyButton
                    visible: root.actionsExpanded
                    text: i18n("Copy") + "  ▾"
                    glyph: "edit-copy"
                    onClicked: actions.popupSection("copy", copyButton)
                }


                }

                PlasmaComponents.ToolButton {
                    id: actionsDisclosure
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    text: root.actionsExpanded ? i18n("Fewer") : i18n("More")
                    icon.name: root.actionsExpanded ? "arrow-up" : "arrow-down"
                    display: PlasmaComponents.AbstractButton.TextBesideIcon
                    onClicked: root.actionsExpanded = !root.actionsExpanded
                }
            }
        }

    }

    // =========================================================== tabs ======

    Component {
        id: overviewComponent

        PlasmaComponents.ScrollView {
            background: null

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
                Components.FieldRow {
                    Layout.fillWidth: true
                    label: i18n("Status")
                    value: root.record.status
                }
                Components.FieldRow {
                    Layout.fillWidth: true
                    label: i18n("Health")
                    value: root.record.health !== "none" ? root.record.health : ""
                }
                Components.FieldRow {
                    Layout.fillWidth: true
                    label: i18n("Image")
                    value: String(root.record.image || "").replace(/@sha256:([0-9a-f]{12})[0-9a-f]+/i, "@sha256:$1…")
                    copyValue: root.record.image
                    copyable: true
                    revealable: true
                    wrap: true
                }
                Components.FieldRow { Layout.fillWidth: true; label: i18n("Project"); value: root.record.project }
                Components.FieldRow { Layout.fillWidth: true; label: i18n("Service"); value: root.record.service }
                Components.FieldRow {
                    Layout.fillWidth: true
                    label: i18n("Ports")
                    value: String(root.record.ports || "").replace(/,(?=\d{3}(?:->|\/|:))/g, "")
                    copyValue: root.record.ports
                    copyable: true
                    wrap: true
                }
                Components.FieldRow { Layout.fillWidth: true; label: i18n("Mounts"); value: root.record.mounts; wrap: true; copyable: true }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    Layout.rightMargin: Kirigami.Units.largeSpacing
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
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    Layout.rightMargin: Kirigami.Units.largeSpacing
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    visible: root.record.isRunning
                        && ((root.record.cpu !== "" && root.record.cpu !== "unavailable")
                            || (root.record.mem !== "" && root.record.mem !== "unavailable"))
                    spacing: Kirigami.Units.largeSpacing
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.record.cpu !== "" && root.record.cpu !== "unavailable"
                        PlasmaComponents.Label { text: i18n("CPU %1", root.record.cpu); font: Kirigami.Theme.smallFont }
                        Components.Sparkline {
                            Layout.fillWidth: true
                            implicitHeight: Kirigami.Units.gridUnit * 2
                            samples: root.backend.revision >= 0 ? root.backend.historyFor(root.record.id).cpu : []
                            color: Kirigami.Theme.positiveTextColor
                            floor: 10
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.record.mem !== "" && root.record.mem !== "unavailable"
                        PlasmaComponents.Label { text: i18n("Memory %1", root.record.mem); font: Kirigami.Theme.smallFont }
                        Components.Sparkline {
                            Layout.fillWidth: true
                            implicitHeight: Kirigami.Units.gridUnit * 2
                            samples: root.backend.revision >= 0 ? root.backend.historyFor(root.record.id).mem : []
                            color: Kirigami.Theme.highlightColor
                            floor: 10
                        }
                    }
                }
                Components.FieldRow {
                    Layout.fillWidth: true
                    label: i18n("Web page")
                    value: root.record.probe === "" ? "" : (root.record.probe === "up" ? i18n("answers (%1 ms)", root.record.probeMs) : i18n("does not answer"))
                }
                Components.FieldRow {
                    Layout.fillWidth: true
                    label: i18n("Image update")
                    value: root.record.updateAvailable ? i18n("a newer version is available") : ""
                }

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
