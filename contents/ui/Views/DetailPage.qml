pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../components" as Components

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
    readonly property var record: {
        backend.revision   // dependency, deliberately read
        return backend.findRecord(recordId)
    }

    readonly property var cfg: plasmoid.configuration
    readonly property var links: backend.linksFor(record)
    readonly property bool hasRecord: record !== null

    property int tab: 0        // 0 overview, 1 logs, 2 inspect, 3 run
    property string runText: ""
    property bool runBusy: false

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
    signal outputRequested(string title, string content, bool live)

    function refreshLogs() {
        if (!root.hasRecord) return
        root.backend.fetchLogs(root.record, root.cfg.logTailLines)
    }

    function refreshInspect() {
        if (!root.hasRecord) return
        root.backend.fetchInspect(root.record)
    }

    onTabChanged: {
        if (tab === 1) root.refreshLogs()
        if (tab === 2 && inspectText === "") root.refreshInspect()
    }

    Connections {
        target: root.backend
        function onOutputReady(title, content) {
            if (title === root.backend.logsTitle(root.record)) {
                root.logsText = content
            } else if (title.indexOf("Inspect") === 0) {
                root.inspectText = content
            }
        }
    }

    Timer {
        // Follow the tail while the logs tab is open. Same cadence as the
        // stats poll, so the two do not fight over the command runner.
        interval: Math.max(2, root.cfg.usageInterval) * 1000
        repeat: true
        running: root.tab === 1 && root.hasRecord
        onTriggered: root.refreshLogs()
    }

    // =========================================================== chrome ====

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // -------------------------------------------------- header -------
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.ToolButton {
                id: backButton
                display: PlasmaComponents.AbstractButton.IconOnly
                icon.name: "go-previous"
                text: i18n("Back")
                onClicked: root.navigator.pop()
                PlasmaComponents.ToolTip { text: backButton.text }
            }

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

            PlasmaComponents.ToolButton {
                id: primaryButton
                display: PlasmaComponents.AbstractButton.IconOnly
                visible: root.hasRecord
                icon.name: root.record && root.record.isRunning
                    ? "media-playback-stop"
                    : "media-playback-start"
                text: root.record && root.record.isRunning ? i18n("Stop") : i18n("Start")
                onClicked: {
                    if (root.record.isRunning) {
                        root.backend.stopContainer(root.record)
                    } else {
                        root.backend.startContainer(root.record)
                    }
                }
                PlasmaComponents.ToolTip { text: primaryButton.text }
            }

            PlasmaComponents.ToolButton {
                id: webButton
                display: PlasmaComponents.AbstractButton.IconOnly
                visible: root.hasRecord && root.record.isRunning && root.links.length > 0
                icon.name: "internet-web-browser"
                text: i18n("Web links")
                onClicked: webActions.popup(webButton, 0, webButton.height)
                PlasmaComponents.ToolTip { text: webButton.text }
            }

            Components.ContainerActions {
                id: webActions
                backend: root.backend
                record: root.record
                dialogs: root.dialogs
                browserOnly: true
            }

            PlasmaComponents.ToolButton {
                id: menuButton
                display: PlasmaComponents.AbstractButton.IconOnly
                visible: root.hasRecord
                icon.name: "application-menu"
                text: i18n("More")
                onClicked: actions.popup(menuButton, 0, menuButton.height)
                PlasmaComponents.ToolTip { text: menuButton.text }
            }

            Components.ContainerActions {
                id: actions
                backend: root.backend
                record: root.record
                dialogs: root.dialogs
                onOpenOutput: function (title, content, live) {
                    root.outputRequested(title, content, live)
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
            spacing: 0

            PlasmaComponents.ToolButton {
                id: tabOverview
                text: i18n("Overview")
                checkable: true
                checked: root.tab === 0
                onClicked: root.tab = 0
            }

            PlasmaComponents.ToolButton {
                id: tabLogs
                text: i18n("Logs")
                checkable: true
                checked: root.tab === 1
                onClicked: root.tab = 1
            }

            PlasmaComponents.ToolButton {
                id: tabInspect
                text: i18n("Inspect")
                checkable: true
                checked: root.tab === 2
                onClicked: root.tab = 2
            }

            PlasmaComponents.ToolButton {
                id: tabRun
                text: i18n("Run")
                visible: root.hasRecord && root.record.isRunning
                checkable: true
                checked: root.tab === 3
                onClicked: root.tab = 3
            }

            Item { Layout.fillWidth: true }

            PlasmaComponents.ToolButton {
                id: logsRefresh
                display: PlasmaComponents.AbstractButton.IconOnly
                visible: root.tab === 1
                icon.name: "view-refresh"
                text: i18n("Refresh logs")
                onClicked: root.refreshLogs()
                PlasmaComponents.ToolTip { text: logsRefresh.text }
            }

            PlasmaComponents.ToolButton {
                id: logsFollow
                display: PlasmaComponents.AbstractButton.IconOnly
                visible: root.tab === 1
                icon.name: "utilities-terminal"
                text: i18n("Follow in terminal")
                onClicked: root.backend.followLogs(root.record)
                PlasmaComponents.ToolTip { text: logsFollow.text }
            }

            PlasmaComponents.ToolButton {
                id: inspectRefresh
                display: PlasmaComponents.AbstractButton.IconOnly
                visible: root.tab === 2
                icon.name: "view-refresh"
                text: i18n("Refresh inspect output")
                onClicked: root.refreshInspect()
                PlasmaComponents.ToolTip { text: inspectRefresh.text }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.alpha(Kirigami.Theme.textColor, 0.2)
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

            contentItem: ColumnLayout {
                width: parent.width
                spacing: 0

                Components.FieldRow {
                    label: i18n("Status")
                    value: root.record.status
                }
                Components.FieldRow {
                    label: i18n("Health")
                    value: root.record.health !== "none" ? root.record.health : ""
                }
                // CPU and memory over the last few minutes.
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    Layout.rightMargin: Kirigami.Units.largeSpacing
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    visible: root.record.isRunning
                    spacing: Kirigami.Units.largeSpacing

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        PlasmaComponents.Label {
                            text: i18n("CPU %1", root.record.cpu)
                            font: Kirigami.Theme.smallFont
                        }
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
                        spacing: 2
                        PlasmaComponents.Label {
                            text: i18n("Memory %1", root.record.mem)
                            font: Kirigami.Theme.smallFont
                        }
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
                    label: i18n("Web page")
                    value: root.record.probe === "" ? ""
                         : (root.record.probe === "up"
                            ? i18n("answers (%1 ms)", root.record.probeMs)
                            : i18n("does not answer"))
                }
                Components.FieldRow {
                    label: i18n("Image")
                    value: root.record.updateAvailable ? i18n("a newer version is available") : ""
                }

                // What Docker does with this container when the daemon starts.
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    Layout.rightMargin: Kirigami.Units.largeSpacing
                    visible: root.record.restartPolicy !== ""
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents.Label {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                        text: i18n("Autostart")
                        color: Kirigami.Theme.disabledTextColor
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }

                    PlasmaComponents.ComboBox {
                        id: policyBox
                        Layout.fillWidth: true
                        readonly property var policies: ["no", "on-failure", "unless-stopped", "always"]
                        model: policies.map(function (p) { return root.backend.policyLabel(p) })
                        currentIndex: Math.max(0, policies.indexOf(root.record.restartPolicy))
                        onActivated: function (index) {
                            if (policies[index] !== root.record.restartPolicy)
                                root.backend.setRestartPolicy(root.record, policies[index])
                        }
                    }
                }
                Components.FieldRow {
                    label: i18n("Image")
                    value: root.record.image
                    copyable: true
                }
                Components.FieldRow {
                    label: i18n("ID")
                    value: root.record.id
                    copyable: true
                }
                Components.FieldRow {
                    label: i18n("Command")
                    value: root.record.command
                    wrap: true
                }
                Components.FieldRow {
                    label: i18n("CPU")
                    value: root.record.cpu
                }
                Components.FieldRow {
                    label: i18n("Memory")
                    value: root.record.memU !== "" ? root.record.memU + "  (" + root.record.mem + ")" : ""
                }
                Components.FieldRow {
                    label: i18n("Net I/O")
                    value: root.record.netio
                }
                Components.FieldRow {
                    label: i18n("Block I/O")
                    value: root.record.blockio
                }
                Components.FieldRow {
                    label: i18n("PIDs")
                    value: root.record.pids
                }
                Components.FieldRow {
                    label: i18n("Project")
                    value: root.record.project
                }
                Components.FieldRow {
                    label: i18n("Service")
                    value: root.record.service
                }
                Components.FieldRow {
                    label: i18n("Networks")
                    value: root.record.networks
                }
                Components.FieldRow {
                    label: i18n("Volumes")
                    value: root.record.localVolumes
                }
                Components.FieldRow {
                    label: i18n("Mounts")
                    value: root.record.mounts
                    wrap: true
                }
                Components.FieldRow {
                    label: i18n("Ports")
                    value: root.record.ports
                    copyable: true
                }
                Components.FieldRow {
                    label: i18n("Compose file")
                    value: root.record.composeFiles
                    wrap: true
                }
                Components.FieldRow {
                    label: i18n("Created")
                    value: root.record.createdAt
                }
                Components.FieldRow {
                    label: i18n("Size")
                    value: root.record.size
                }
                Components.FieldRow {
                    label: i18n("Platform")
                    value: root.record.platform
                }

                // ---- published ports as real, clickable buttons ----
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    Layout.bottomMargin: Kirigami.Units.largeSpacing
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
                            delegate: PlasmaComponents.Button {
                                required property var modelData
                                icon.name: "internet-web-browser"
                                text: i18n("%1 — :%2", modelData.label, modelData.port)
                                onClicked: root.backend.openLink(modelData)
                            }
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
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
                    font.family: "monospace"
                    enabled: !root.runBusy
                    onAccepted: { root.runCommand(text); selectAll() }
                }

                PlasmaComponents.Button {
                    text: i18n("Run")
                    icon.name: "media-playback-start"
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

        Components.LogViewer {
            text: root.inspectText !== "" ? root.inspectText : i18n("Loading…")
            wrap: false
        }
    }
}
