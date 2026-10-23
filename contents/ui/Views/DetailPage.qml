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
    readonly property var can: backend.actionsFor(record)
    readonly property var stateCan: backend.stateActionsFor(record)
    readonly property var primary: backend.primaryActionFor(record)
    readonly property bool isNotCreated: root.hasRecord && root.record.state === "not-created"

    property int tab: 0        // 0 overview, 1 logs, 2 inspect, 3 run
    property string runText: ""
    property bool runBusy: false
    property string logsRequestId: ""
    property string inspectRequestId: ""
    property int logsSequence: 0
    property int inspectSequence: 0

    /* Restarts, last exit, addresses and limits; read when the state changes. */
    property var facts: null
    readonly property string factsKey: root.hasRecord ? root.record.id + "|" + root.record.state + "|" + root.record.status.replace(/\d+ (seconds?|minutes?|hours?|days?|weeks?)/, "") : ""
    onFactsKeyChanged: factsTimer.restart()
    Timer {
        id: factsTimer
        interval: 300
        onTriggered: if (root.hasRecord && !root.isNotCreated) root.backend.fetchFacts(root.record, function (f) { root.facts = f })
    }
    function since(ms) {
        if (!ms) return ""
        const minutes = Math.round((Date.now() - ms) / 60000)
        const ago = minutes < 1 ? i18n("just now") : minutes < 60 ? i18np("%1 minute ago", "%1 minutes ago", minutes)
            : minutes < 2880 ? i18np("%1 hour ago", "%1 hours ago", Math.round(minutes / 60)) : i18np("%1 day ago", "%1 days ago", Math.round(minutes / 1440))
        return i18n("%1 · %2", ago, new Date(ms).toLocaleString(Qt.locale(), Locale.ShortFormat))
    }
    function bytes(value) {
        const units = ["B", "KiB", "MiB", "GiB", "TiB"]
        let i = 0
        while (value >= 1024 && i < units.length - 1) { value /= 1024; i++ }
        return (i === 0 ? String(value) : value.toFixed(value >= 10 ? 0 : 1)) + " " + units[i]
    }
    readonly property string lastExit: {
        const f = root.facts
        if (!f || f.finishedAt === 0 || (root.record.isRunning && f.restarts === 0)) return ""
        let text = f.exitCode >= 0 ? i18n("Exit code %1", f.exitCode) : ""
        if (f.oomKilled) text += (text ? " · " : "") + i18n("out of memory")
        if (f.error) text += (text ? " · " : "") + f.error
        return text + (text ? " · " : "") + root.since(f.finishedAt)
    }

    Component.onCompleted: {
        pageGeneration = backend.generation
        if (!root.isNotCreated) {
            logsRequestId = backend.newOutputRequest("logs", recordId)
            inspectRequestId = backend.newOutputRequest("inspect", recordId)
        }
        // Opened straight on a tab (Full Logs, Doctor): onTabChanged ran before
        // the request ids existed, so load that tab now.
        if (root.isNotCreated) root.tab = 0
        else if (tab === 1) root.refreshLogs()
        else if (tab === 2) root.refreshInspect()
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
        case "not-created": return i18n("Undeployed")
        case "running": return i18n("Running")
        default: return i18n("Stopped")
        }
    }
    /* State and health in one badge: "Running · Healthy", "Running · Starting". */
    readonly property string statusText: {
        const health = root.hasRecord && root.record.isRunning === true ? String(root.record.health || "") : ""
        if (root.attention === "running" && health === "healthy") return i18n("%1 · Healthy", root.stateWord)
        if (root.attention === "running" && health === "starting") return i18n("%1 · Starting", root.stateWord)
        return root.stateWord
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
            stackActions: root.narrow
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
                    text: root.statusText
                    tone: root.badgeInfo.tone
                    variant: root.badgeInfo.variant
                    glyph: root.badgeInfo.glyph
                    statusDot: root.badgeInfo.dot
                    pulse: root.badgeInfo.dot
                },
                Components.Pill {
                    visible: root.hasRecord && root.record.updateAvailable === true
                    text: i18n("Update available")
                    tone: "violet"
                    glyph: "cloud-download"
                }
            ]

            // Shown when the state allows the action, greyed while another runs
            // (lib/actions.js, shared with the menu and the list).
            Components.DockButton {
                visible: root.hasRecord && root.stateCan[root.primary.action] === true
                enabled: root.primary.enabled
                variant: root.primary.action === "stop" ? "default" : "primary"
                iconOnly: root.narrow
                glyph: root.primary.action === "stop" ? "media-playback-stop" : "media-playback-start"
                text: root.primary.action === "create" ? i18n("Create and start") : root.primary.action === "stop" ? i18n("Stop") : i18n("Start")
                onClicked: root.backend.runAction(root.record, root.primary.action)
            }
            Components.DockButton {
                visible: root.stateCan.restart === true
                enabled: root.can.restart === true
                iconOnly: root.narrow
                glyph: "view-refresh"
                text: i18n("Restart")
                onClicked: root.backend.runAction(root.record, "restart")
            }
            Components.DockButton {
                visible: root.stateCan.pause === true || root.stateCan.resume === true
                enabled: root.can.pause === true || root.can.resume === true
                iconOnly: root.narrow
                glyph: root.stateCan.resume ? "media-playback-start" : "media-playback-pause"
                text: root.stateCan.resume ? i18n("Resume") : i18n("Pause")
                onClicked: root.backend.runAction(root.record, root.stateCan.resume ? "resume" : "pause")
            }
            Components.DockButton {
                visible: root.stateCan.kill === true
                enabled: root.can.kill === true
                iconOnly: root.narrow
                variant: "danger"
                glyph: "process-stop"
                text: i18n("Kill")
                PlasmaComponents.ToolTip.text: i18n("Force stop now, without a graceful shutdown")
                PlasmaComponents.ToolTip.visible: hovered && !root.narrow
                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                onClicked: root.backend.runAction(root.record, "kill")
            }
            Components.DockButton {
                visible: root.stateCan.update === true
                enabled: root.can.update === true
                iconOnly: root.narrow
                glyph: "cloud-download"
                // Violet when the registry has a newer image; otherwise a plain pull-and-recreate.
                iconTone: root.record && root.record.updateAvailable ? "violet" : ""
                text: i18n("Update")
                PlasmaComponents.ToolTip.text: root.record && root.record.updateAvailable
                    ? i18n("A newer image is available: pull it and recreate the container")
                    : i18n("Pull the latest image and recreate the container")
                PlasmaComponents.ToolTip.visible: hovered && !root.narrow
                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                onClicked: root.dialogs.confirmUpdate(root.record)
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
            // The preferred address is the accent button; the others sit beside it.
            // Each says which network it uses, so LAN and Tailscale read apart at a glance.
            Repeater {
                model: root.links
                delegate: Components.DockButton {
                    required property var modelData
                    required property int index
                    readonly property string where: String(modelData.label || "")
                    variant: index === 0 ? "primary" : "default"
                    glyph: where === "LAN" ? "house" : where === "Tailscale" ? "shield"
                        : where === "localhost" ? "monitor" : "globe"
                    text: (where !== "" ? where : i18n("Web UI")) + "  :" + String(modelData.port || "")
                    onClicked: root.backend.openLink(modelData)
                    PlasmaComponents.ToolTip.text: i18n("Open %1", modelData.url || Parsers.linkUrl(modelData))
                    PlasmaComponents.ToolTip.visible: hovered
                    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
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
            // These have their own buttons in the page header.
            excludedActions: ["details", "start", "stop", "create and start", "restart", "logs", "open web ui", "pause", "resume", "kill", "update"]
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

    /* Usable value, or "" for the empty and "unavailable" placeholders. */
    function shown(value) {
        const text = String(value === undefined || value === null ? "" : value)
        return text === "unavailable" || text === "—" ? "" : text
    }
    /* "a, b" lists (ports, mounts, networks) one entry per line. */
    function lines(value) {
        return root.shown(value).split(/,\s*(?![^\[]*\])/).map(function (v) { return v.trim() })
            .filter(function (v, i, all) { return v !== "" && all.indexOf(v) === i }).join("\n")
    }
    /* Remembered while the page is open, so switching tabs keeps folds. */
    property var folded: ({})
    function setFolded(key, value) {
        const next = Object.assign({}, root.folded)
        next[key] = value
        root.folded = next
    }

    component Metric: ColumnLayout {
        id: metric
        property string caption: ""
        property string value: ""
        property color tint: Kirigami.Theme.textColor
        visible: value !== ""
        spacing: 0
        Layout.fillWidth: true
        Layout.minimumWidth: Kirigami.Units.gridUnit * 5
        PlasmaComponents.Label {
            text: metric.caption
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        PlasmaComponents.Label {
            text: metric.value
            color: metric.tint
            font.bold: true
            font.features: ({"tnum": 1})
            elide: Text.ElideRight
            Layout.fillWidth: true
            PlasmaComponents.ToolTip { text: metric.value }
        }
    }

    component Section: Components.Card {
        id: section
        property string key: ""
        Layout.fillWidth: true
        padding: Kirigami.Units.smallSpacing * 2
        collapsible: true
        prominentTitle: true
        expanded: root.folded[section.key] !== true
        onExpandedChanged: if (root.folded[section.key] === expanded) root.setFolded(section.key, !expanded)
    }

    Component {
        id: overviewComponent

        PlasmaComponents.ScrollView {
            id: overviewScroll
            background: null
            PlasmaComponents.ScrollBar.vertical.policy: PlasmaComponents.ScrollBar.AlwaysOn

            contentItem: Flickable {
                objectName: "detailOverviewScroll"
                contentWidth: width
                contentHeight: overviewFields.implicitHeight + Kirigami.Units.largeSpacing * 2
                clip: true

                // Two columns once each card has room for a label and a value.
                GridLayout {
                    id: overviewFields
                    readonly property bool twoColumns: width >= Kirigami.Units.gridUnit * 38
                    x: Kirigami.Units.largeSpacing
                    y: Kirigami.Units.largeSpacing
                    width: parent.width - Kirigami.Units.largeSpacing * 2
                    columns: twoColumns ? 2 : 1
                    columnSpacing: Kirigami.Units.largeSpacing
                    rowSpacing: Kirigami.Units.largeSpacing
                    uniformCellWidths: true

                    PlasmaComponents.Label {
                        objectName: "detailNotCreatedMessage"
                        Layout.fillWidth: true
                        Layout.columnSpan: overviewFields.columns
                        visible: root.isNotCreated
                        wrapMode: Text.WordWrap
                        text: i18n("This Compose service is configured, but its container has not been created yet. Create and start it to inspect logs or run commands.")
                        color: Kirigami.Theme.neutralTextColor
                    }

                    // ------------------------------------------ left column --
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: 1
                        spacing: Kirigami.Units.largeSpacing

                        Section {
                            key: "overview"
                            titleTone: "blue"
                            title: i18n("Overview")
                            titleGlyph: "badge-info"
                            titleHint: root.shown(root.record.status)
                            Components.FieldRow { Layout.fillWidth: true; glyph: "activity"; label: i18n("Status"); value: root.shown(root.record.status) }
                            Components.FieldRow { Layout.fillWidth: true; glyph: "heart-pulse"; label: i18n("Health"); value: root.record.health !== "none" ? root.shown(root.record.health) : "" }
                            Components.FieldRow { Layout.fillWidth: true; glyph: "play"; label: i18n("Started"); value: root.facts && root.record.isRunning ? root.since(root.facts.startedAt) : "" }
                            Components.FieldRow {
                                Layout.fillWidth: true; glyph: "rotate-cw"; label: i18n("Restarts")
                                glyphTone: root.facts && root.facts.restarts > 0 ? "warn" : "muted"
                                value: root.facts && root.facts.restarts > 0 ? i18np("%1 restart since created", "%1 restarts since created", root.facts.restarts) : ""
                            }
                            Components.FieldRow {
                                Layout.fillWidth: true; glyph: "circle-x"; label: i18n("Last exit"); wrap: true
                                glyphTone: root.facts && (root.facts.exitCode > 0 || root.facts.oomKilled) ? "bad" : "muted"
                                value: root.lastExit
                            }
                            Components.FieldRow {
                                Layout.fillWidth: true
                                glyph: "box"
                                label: i18n("Image")
                                value: String(root.record.image || "").replace(/@sha256:([0-9a-f]{12})[0-9a-f]+/i, "@sha256:$1…")
                                copyValue: root.record.image
                                copyable: true
                                wrap: true
                            }
                            Components.FieldRow { Layout.fillWidth: true; glyph: "folder-kanban"; label: i18n("Project"); value: root.shown(root.record.project) }
                            Components.FieldRow { Layout.fillWidth: true; glyph: "workflow"; label: i18n("Service"); value: root.shown(root.record.service) }
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: Kirigami.Units.largeSpacing
                                Layout.rightMargin: Kirigami.Units.largeSpacing
                                Layout.topMargin: Kirigami.Units.smallSpacing
                                visible: root.record.restartPolicy !== ""
                                spacing: Kirigami.Units.smallSpacing
                                PlasmaComponents.Label { Layout.preferredWidth: Kirigami.Units.gridUnit * 7; text: i18n("Autostart"); color: Kirigami.Theme.disabledTextColor }
                                Components.SizedComboBox {
                                    enabled: !root.backend.readOnly && !root.backend.isPodman
                                    preferredTextWidth: Kirigami.Units.gridUnit * 6
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
                                glyphTone: root.record.probe === "up" ? "ok" : root.record.probe === "down" ? "bad" : "muted"
                                label: i18n("Web page")
                                value: root.record.probe === "" ? "" : (root.record.probe === "up" ? i18n("answers (%1 ms)", root.record.probeMs) : i18n("does not answer"))
                            }
                            Components.FieldRow {
                                Layout.fillWidth: true
                                glyph: "cloud-download"
                                glyphTone: "violet"
                                label: i18n("Image update")
                                value: root.record.updateAvailable ? i18n("a newer version is available") : ""
                            }
                        }

                        Section {
                            key: "container"
                            titleTone: "slate"
                            title: i18n("Container")
                            titleGlyph: "box"
                            titleHint: String(root.record.id).slice(0, 12)
                            Components.FieldRow {
                                Layout.fillWidth: true
                                glyph: "hash"
                                label: i18n("ID")
                                value: String(root.record.id).length > 12 ? String(root.record.id).slice(0, 12) + "…" : root.record.id
                                copyValue: root.record.id
                                copyable: true
                                revealable: true
                            }
                            Components.FieldRow { Layout.fillWidth: true; glyph: "terminal"; label: i18n("Command"); value: root.shown(root.record.command); wrap: true; copyable: true }
                            Components.FieldRow { Layout.fillWidth: true; glyph: "file-text"; label: i18n("Compose file"); value: root.lines(root.record.composeFiles); copyValue: root.record.composeFiles; wrap: true; copyable: true }
                            Components.FieldRow { Layout.fillWidth: true; glyph: "calendar"; label: i18n("Created"); value: root.shown(root.record.createdAt) }
                            Components.FieldRow { Layout.fillWidth: true; glyph: "cpu"; label: i18n("Platform"); value: root.shown(root.record.platform) }
                            Components.FieldRow {
                                Layout.fillWidth: true; glyph: "gauge"; label: i18n("Limits")
                                value: !root.facts ? "" : (root.facts.memoryLimit || root.facts.cpuLimit)
                                    ? [root.facts.memoryLimit ? i18n("Memory %1", root.bytes(root.facts.memoryLimit)) : "",
                                       root.facts.cpuLimit ? i18np("%1 CPU", "%1 CPUs", root.facts.cpuLimit) : ""].filter(function (v) { return v !== "" }).join(" · ")
                                    : i18n("None (may use the whole host)")
                            }
                            Components.FieldRow {
                                Layout.fillWidth: true; glyph: "heart-pulse"; label: i18n("Health check"); wrap: true; copyable: true
                                value: root.facts && root.facts.healthCheck !== "" ? root.facts.healthCheck + (root.facts.healthInterval ? "  " + i18n("(every %1 s)", root.facts.healthInterval) : "") : ""
                                copyValue: root.facts ? root.facts.healthCheck : ""
                            }
                            Components.FieldRow { Layout.fillWidth: true; glyph: "user"; label: i18n("User"); value: root.facts ? root.facts.user : "" }
                            Components.FieldRow { Layout.fillWidth: true; glyph: "folder"; label: i18n("Working dir"); value: root.facts && root.facts.workdir !== "/" ? root.facts.workdir : "" }
                        }

                        Section {
                            key: "storage"
                            titleTone: "amber"
                            visible: root.shown(root.record.mounts) !== "" || (root.shown(root.record.localVolumes) !== "" && root.record.localVolumes !== "0") || root.shown(root.record.size) !== ""
                            title: i18n("Storage")
                            titleGlyph: "hard-drive"
                            Components.FieldRow { Layout.fillWidth: true; glyph: "folder"; label: i18n("Mounts"); value: root.lines(root.record.mounts); copyValue: root.record.mounts; wrap: true; copyable: true }
                            Components.FieldRow { Layout.fillWidth: true; glyph: "database"; label: i18n("Local volumes"); value: root.record.localVolumes !== "0" ? root.shown(root.record.localVolumes) : "" }
                            Components.FieldRow { Layout.fillWidth: true; glyph: "package"; label: i18n("Size"); value: /^0\s*B$/.test(String(root.record.size)) ? "" : root.shown(root.record.size) }
                        }

                    }

                    // ----------------------------------------- right column --
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: 1
                        spacing: Kirigami.Units.largeSpacing

                        Section {
                            key: "usage"
                            titleTone: "cyan"
                            visible: root.record.isRunning === true
                            title: i18n("Usage")
                            titleGlyph: "gauge"
                            titleHint: [root.shown(root.record.cpu), root.shown(root.record.memU)].filter(function (v) { return v !== "" }).join(" · ")

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: Kirigami.Units.largeSpacing
                                Layout.rightMargin: Kirigami.Units.largeSpacing
                                spacing: Kirigami.Units.largeSpacing
                                visible: root.shown(root.record.cpu) !== "" || root.shown(root.record.mem) !== ""
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    visible: root.shown(root.record.cpu) !== ""
                                    spacing: 2
                                    PlasmaComponents.Label { text: i18n("CPU %1", root.record.cpu); font: Kirigami.Theme.smallFont; color: Style.HUE.cyan }
                                    Components.Sparkline {
                                        Layout.fillWidth: true
                                        implicitHeight: Kirigami.Units.gridUnit * 2.2
                                        samples: root.backend.revision >= 0 ? root.backend.historyFor(root.record.id).cpu : []
                                        color: Style.HUE.cyan
                                        floor: 10
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    visible: root.shown(root.record.mem) !== ""
                                    spacing: 2
                                    PlasmaComponents.Label { text: i18n("Memory %1", root.record.mem); font: Kirigami.Theme.smallFont; color: Style.HUE.fuchsia }
                                    Components.Sparkline {
                                        Layout.fillWidth: true
                                        implicitHeight: Kirigami.Units.gridUnit * 2.2
                                        samples: root.backend.revision >= 0 ? root.backend.historyFor(root.record.id).mem : []
                                        color: Style.HUE.fuchsia
                                        floor: 10
                                    }
                                }
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: Kirigami.Units.largeSpacing
                                Layout.rightMargin: Kirigami.Units.largeSpacing
                                Layout.topMargin: Kirigami.Units.smallSpacing
                                columns: Math.max(2, Math.floor(width / (Kirigami.Units.gridUnit * 6)))
                                columnSpacing: Kirigami.Units.largeSpacing
                                rowSpacing: Kirigami.Units.smallSpacing
                                Metric { caption: i18n("Memory used"); value: root.shown(root.record.memU) }
                                Metric { caption: i18n("Net I/O"); value: root.shown(root.record.netio) }
                                Metric { caption: i18n("Block I/O"); value: root.shown(root.record.blockio) }
                                Metric { caption: i18n("Processes"); value: root.shown(root.record.pids) }
                            }
                        }

                        Section {
                            key: "network"
                            titleTone: "violet"
                            visible: root.shown(root.record.ports) !== "" || root.shown(root.record.networks) !== "" || root.links.length > 0
                            title: i18n("Network")
                            titleGlyph: "network"
                            titleHint: root.links.length > 0 ? i18np("%1 link", "%1 links", root.links.length) : ""
                            Components.FieldRow {
                                Layout.fillWidth: true
                                glyph: "plug"
                                label: i18n("Ports")
                                value: root.lines(String(root.record.ports || "").replace(/,(?=\d{3}(?:->|\/|:))/g, ""))
                                copyValue: root.record.ports
                                copyable: true
                                wrap: true
                            }
                            Components.FieldRow {
                                Layout.fillWidth: true; glyph: "network"; label: i18n("Networks"); wrap: true; copyable: true
                                // With addresses once they are known: "media_net · 172.18.0.5".
                                value: root.facts && root.facts.networks.length > 0
                                    ? root.facts.networks.map(function (n) { return n.name + "  ·  " + [n.ip, n.ipv6].filter(function (v) { return v !== "" }).join(", ") }).join("\n")
                                    : root.lines(root.record.networks)
                                copyValue: root.facts && root.facts.networks.length > 0 ? root.facts.networks.map(function (n) { return n.ip }).join(" ") : root.record.networks
                            }
                            Repeater {
                                model: root.record.isRunning ? root.links : []
                                delegate: Components.FieldRow {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    glyph: "insert-link"
                                    glyphTone: "info"
                                    label: String(modelData.label || i18n("Web UI"))
                                    value: modelData.url || Parsers.linkUrl(modelData)
                                    copyable: true
                                }
                            }
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
