import QtQuick
import QtQuick.Layouts
import "../../lib/parsers.js" as Parsers
import "../../lib/status.js" as Status
import "../../lib/style.js" as Style

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

/*
 * ContainerRow — one container, rendered at one of four detail levels.
 *
 *   0 minimal   identity and compact status (handled by ContainerChips)
 *   1 normal    + resource usage and primary actions
 *   2 detailed  + image, project and published ports
 *   3 verbose   + id, project, network, mounts, I/O, pids, uptime
 *
 * The levels share a single delegate rather than being four separate ones, so
 * everything stays aligned between them and switching level never rebuilds the
 * list. Hidden rows simply collapse out of the layout, which is what makes the
 * jump from minimal to verbose feel like the same list getting more honest
 * rather than a different screen.
 */
PlasmaComponents.ItemDelegate {
    id: root

    required property var backend
    required property var dialogs
    required property int index
    required property int detailLevel

    /*
     * The row's data arrives as ListModel roles, so each one the row renders is
     * declared as a required property. The alternative -- `required property var
     * model` plus `root.name` -- does not work here: declaring a property named
     * `model` shadows the delegate's own model context, which is what produced
     * a delegate whose every binding read "undefined".
     *
     * `id` is a reserved word in QML, so the container id arrives as the
     * `containerKey` role (DockerBackend publishes both).
     */
    required property string containerKey
    required property string name
    required property string image
    required property string runningFor
    required property string containerState
    required property string status
    required property string health
    required property bool isRunning
    required property string localVolumes
    required property string networks
    required property string size
    required property string platform
    required property string project
    required property string service
    required property string cpu
    required property string mem
    required property string blockio
    required property string netio
    required property string pids
    required property real cpuPct
    required property real memPct
    required property string ports
    required property string composeFiles
    required property string composeWorkDir

    /*
     * The backend and the action menu work on whole record objects, so rebuild
     * one from the roles. This is also what lets ContainerActions stay ignorant
     * of how the list happens to be fed.
     */
    readonly property var record: {
        return root.backend.revision >= 0 ? root.backend.findRecord(root.containerKey) || {id: root.containerKey, name: root.name, image: root.image,
            state: root.containerState, isRunning: root.isRunning, pinned: false, updateAvailable: false,
            restartPolicy: "", probe: "", project: root.project, service: "", ports: root.ports,
            composeFiles: root.composeFiles, composeWorkDir: root.composeWorkDir} : null
    }

    signal openDetail(string recordId)
    signal openOutput(string title, string content, bool live, string recordId)

    readonly property var cfg: plasmoid.configuration
    readonly property var operation: backend.operationsRevision >= 0 ? backend.operationFor(containerKey) : ({busy:false,label:"",ok:true})
    readonly property string attention: Status.attentionKind(root.record)
    readonly property bool compactMetrics: root.width < 560
    /* Below this there is no room for a column of its own for the state. */
    readonly property bool narrow: root.width < Kirigami.Units.gridUnit * 29
    readonly property bool hasStats: root.isRunning && root.cpu !== ""

    /* 0 means "follow the panel scale"; anything else is a pixel override. */
    readonly property int iconSize: Math.max(cfg.rowIconSize > 0 ? cfg.rowIconSize : 24,
        root.detailLevel === 3 ? Kirigami.Units.iconSizes.large : 0)
    readonly property var links: backend.linksFor(root.record)

    implicitHeight: layout.implicitHeight + Kirigami.Units.smallSpacing * 2
    width: ListView.view ? ListView.view.width : implicitWidth
    highlighted: false
    background: Rectangle {
        radius: Kirigami.Units.smallSpacing
        color: root.ListView.isCurrentItem ? Qt.alpha(Kirigami.Theme.highlightColor, Style.WASH.selected)
            : root.hovered ? Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface2) : "transparent"
        border.width: root.ListView.isCurrentItem ? 1.5 : 0
        border.color: Qt.alpha(Kirigami.Theme.highlightColor, Style.WASH_BORDER.selected)
    }

    // --------------------------------------------------------- content ---

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        StateDot {
            Layout.alignment: root.detailLevel === 3 ? Qt.AlignTop : Qt.AlignVCenter
            Layout.topMargin: root.detailLevel === 3 ? Kirigami.Units.smallSpacing * 1.5 : 0
            containerState: root.record.state
            health: root.cfg.showHealth ? (root.record.health || root.health || "none") : "none"
            showHealth: root.cfg.showHealth
            failed: root.attention === "failed"
        }

        ServiceIcon {
            backend: root.backend
            record: root.record
            iconSize: root.iconSize
            Layout.alignment: root.detailLevel === 3 ? Qt.AlignTop : Qt.AlignVCenter
            Layout.topMargin: root.detailLevel === 3 ? Kirigami.Units.smallSpacing : 0
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 1

            // -- name and health indicators -------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Label {
                    Layout.fillWidth: false
                    Layout.maximumWidth: Math.max(72, layout.width * 0.55)
                    Layout.minimumWidth: 72
                    text: root.record.name
                    HoverHandler { id: nameHover }
                    PlasmaComponents.ToolTip { visible: nameHover.hovered; text: root.record.name }
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize
                    font.bold: true
                    elide: Text.ElideRight
                }
                Kirigami.Icon {
                    visible: root.record.pinned === true
                    source: "window-pin"
                    implicitWidth: Kirigami.Units.iconSizes.small * 0.75
                    implicitHeight: implicitWidth
                    opacity: 0.55
                }
                PlasmaComponents.Label {
                    visible: root.record.updateAvailable === true
                    text: i18n("update")
                    color: Style.HUE.violet
                    font: Kirigami.Theme.smallFont
                    TapHandler { onTapped: root.dialogs.confirmUpdate(root.record) }
                    HoverHandler { id: updateHover; cursorShape: Qt.PointingHandCursor }
                    PlasmaComponents.ToolTip { visible: updateHover.hovered; text: i18n("A newer image is available. Use the menu to update.") }
                }
                Rectangle {
                    visible: root.record.probe === "up" || root.record.probe === "down"
                    implicitWidth: Kirigami.Units.smallSpacing * 1.5
                    implicitHeight: implicitWidth
                    radius: width / 2
                    color: root.record.probe === "up" ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
                    HoverHandler { id: probeHover }
                    PlasmaComponents.ToolTip {
                        visible: probeHover.hovered
                        text: root.record.probe === "up" ? i18n("Web page answers (%1 ms)", root.record.probeMs) : i18n("Web page does not answer")
                    }
                }
                Kirigami.Icon {
                    visible: root.cfg.showRestartPolicy && root.backend.startsAutomatically(root.record.restartPolicy)
                    source: "media-playlist-repeat"
                    implicitWidth: Kirigami.Units.iconSizes.small * 0.75
                    implicitHeight: implicitWidth
                    opacity: 0.55
                    HoverHandler { id: policyHover }
                    PlasmaComponents.ToolTip { visible: policyHover.hovered; text: root.backend.policyLabel(root.record.restartPolicy) }
                }
                PlasmaComponents.Label {
                    visible: root.record.isRunning && root.record.health === "starting" && root.cfg.showHealth
                    text: i18n("starting")
                    color: Kirigami.Theme.highlightColor
                    font: root.detailLevel === 3 ? Kirigami.Theme.defaultFont : Kirigami.Theme.smallFont
                }
                Item { Layout.fillWidth: true }
            }

            // -- image, and the state when there is no room for its own column --
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                visible: root.detailLevel >= 1
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: String(root.record.image).replace(/(@sha256:)[a-f0-9]{20,}/, function(_,prefix) { return prefix + String(root.record.image).split("@sha256:")[1].slice(0,12) + "…" })
                    HoverHandler { id: imageHover }
                    PlasmaComponents.ToolTip { visible: imageHover.hovered; text: root.record.image }
                    elide: Text.ElideMiddle
                    font: root.detailLevel === 3 ? Kirigami.Theme.defaultFont : Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                }
                StatusLine {
                    visible: root.narrow
                    status: root.record.status; containerState: root.record.state; runningFor: root.record.runningFor
                    isRunning: root.record.isRunning === true
                    attention: root.attention
                    operationLabel: root.operation.label; operationOk: root.operation.ok; operationBusy: root.operation.busy
                    glyphMode: "none"; badge: true
                }
            }

            // -- ports (level >= 2) ----------------------------------
            PlasmaComponents.Label {
                id: diagnosticLabel0
                Layout.fillWidth: true
                visible: root.detailLevel >= 2 && root.links.length > 0
                text: i18n("Open: %1", root.links.map(function (l) {
                    return ":" + l.port + " (" + l.label + ")"
                }).join("  "))
                HoverHandler { id: fieldHover0 }
                PlasmaComponents.ToolTip { visible: fieldHover0.hovered; text: diagnosticLabel0.text }
                elide: Text.ElideRight
                font: root.detailLevel === 3 ? Kirigami.Theme.defaultFont : Kirigami.Theme.smallFont
                color: Kirigami.Theme.highlightColor
            }

            // -- everything else (level 3) ---------------------------
            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: root.detailLevel >= 3
                text: i18n("ID: %1", String(root.record.id).slice(0,12))
                HoverHandler { id: identityHover }
                PlasmaComponents.ToolTip { visible: identityHover.hovered; text: root.record.id }
                elide: Text.ElideMiddle
                font: root.detailLevel === 3 ? Kirigami.Theme.defaultFont : Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
            }

            PlasmaComponents.Label {
                id: diagnosticLabel1
                Layout.fillWidth: true
                visible: root.detailLevel >= 2 && root.record.project !== ""
                text: i18n("Project: %1%2", root.record.project,
                           root.record.service !== ""
                               ? i18n(" · %1", root.record.service)
                               : "")
                HoverHandler { id: fieldHover1 }
                PlasmaComponents.ToolTip { visible: fieldHover1.hovered; text: diagnosticLabel1.text }
                elide: Text.ElideRight
                font: root.detailLevel === 3 ? Kirigami.Theme.defaultFont : Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
            }

            PlasmaComponents.Label {
                id: diagnosticLabel2
                Layout.fillWidth: true
                visible: root.detailLevel >= 3 && root.record.networks !== ""
                text: i18n("Networks: %1 · Volumes: %2", root.record.networks, root.record.localVolumes)
                HoverHandler { id: fieldHover2 }
                PlasmaComponents.ToolTip { visible: fieldHover2.hovered; text: diagnosticLabel2.text }
                elide: Text.ElideRight
                font: root.detailLevel === 3 ? Kirigami.Theme.defaultFont : Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
            }

            PlasmaComponents.Label {
                id: diagnosticLabel3
                Layout.fillWidth: true
                visible: root.detailLevel >= 3 && root.hasStats && (!!root.record.netio || !!root.record.blockio || !!root.record.pids)
                text: [root.record.netio ? i18n("Net I/O: %1",root.record.netio) : "", root.record.blockio ? i18n("Block I/O: %1",root.record.blockio) : "", root.record.pids ? i18n("PIDs: %1",root.record.pids) : ""].filter(function(x) { return x !== "" }).join(" · ")
                HoverHandler { id: fieldHover3 }
                PlasmaComponents.ToolTip { visible: fieldHover3.hovered; text: diagnosticLabel3.text }
                elide: Text.ElideRight
                font: root.detailLevel === 3 ? Kirigami.Theme.defaultFont : Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
            }

            PlasmaComponents.Label {
                id: diagnosticLabel4
                Layout.fillWidth: true
                visible: root.detailLevel >= 3
                text: i18n("Uptime: %1 · Size: %2 · Platform: %3",
                           root.record.runningFor, root.record.size,
                           root.record.platform !== "" ? root.record.platform : "—")
                HoverHandler { id: fieldHover4 }
                PlasmaComponents.ToolTip { visible: fieldHover4.hovered; text: diagnosticLabel4.text }
                elide: Text.ElideRight
                font: root.detailLevel === 3 ? Kirigami.Theme.defaultFont : Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
            }
            Flow {
                visible: root.detailLevel === 3
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                spacing: Kirigami.Units.smallSpacing
                ActionButton { text: i18n("Details"); glyph: "document-view"; onClicked: root.openDetail(root.record.id) }
                ActionButton {
                    text: i18n("Logs")
                    glyph: "text-x-generic"
                    onClicked: {
                        root.backend.newOutputRequest("logs", root.record.id)
                        root.openOutput(root.backend.logsTitle(root.record), i18n("Loading…"), true, root.record.id)
                    }
                }
                ActionToolButton {
                    text: i18n("Inspect container JSON")
                    glyph: "document-properties"
                    onClicked: {
                        var generation = root.backend.generation
                        var requestId = root.backend.newOutputRequest("inspect", root.record.id)
                        root.openOutput(i18n("Inspect — %1", root.record.name), i18n("Loading…"), false, root.record.id)
                        root.backend.fetchInspect(root.record, requestId, generation)
                    }
                }
                ActionToolButton {
                    text: i18n("Restart container")
                    glyph: "view-refresh"
                    enabled: !root.backend.readOnly && (root.record.isRunning || root.record.state === "exited")
                    onClicked: root.backend.restartContainer(root.record)
                }
                ActionToolButton {
                    text: root.record.state === "paused" ? i18n("Resume container") : i18n("Pause container")
                    glyph: root.record.state === "paused" ? "media-playback-start" : "media-playback-pause"
                    enabled: !root.backend.readOnly && (Parsers.canPause(root.record.state) || Parsers.canUnpause(root.record.state))
                    onClicked: root.record.state === "paused" ? root.backend.unpauseContainer(root.record) : root.backend.pauseContainer(root.record)
                }
                ActionToolButton {
                    text: root.record.state === "not-created" ? i18n("Create and start service") : root.record.isRunning ? i18n("Stop container") : i18n("Start container")
                    glyph: root.record.isRunning ? "media-playback-stop" : "media-playback-start"
                    enabled: !root.backend.readOnly && (root.record.isRunning ? Parsers.canStop(root.record.state) : Parsers.canStart(root.record.state))
                    onClicked: root.record.isRunning ? root.backend.stopContainer(root.record) : root.backend.startContainer(root.record)
                }
                ActionToolButton {
                    text: i18n("Web links")
                    glyph: "insert-link"
                    visible: root.record.isRunning && root.links.length > 0
                    onClicked: webActions.popup(this, 0, height)
                }
                ActionToolButton {
                    text: root.record.project && root.record.service && root.backend.canUseCompose ? i18n("Update service…") : i18n("Pull latest image…")
                    glyph: "package-upgrade"
                    enabled: !root.backend.readOnly
                    onClicked: root.dialogs.confirmUpdate(root.record)
                }
                ActionToolButton {
                    text: i18n("Edit Compose file…")
                    glyph: "document-edit"
                    visible: root.record.composeFiles !== ""
                    onClicked: root.backend.editCompose(root.record)
                }
            }
        }

        // ---------------------------------------------- state and usage columns --
        StatusLine {
            visible: root.detailLevel >= 1 && !root.narrow
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Kirigami.Units.gridUnit * 8.5
            status: root.record.status; containerState: root.record.state; runningFor: root.record.runningFor
            isRunning: root.record.isRunning === true
            attention: root.attention
            operationLabel: root.operation.label; operationOk: root.operation.ok; operationBusy: root.operation.busy
            glyphMode: "none"; badge: true
        }
        Item {
            visible: root.detailLevel >= 1 && root.width >= Kirigami.Units.gridUnit * 38 && root.cfg.showResourceBars
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Kirigami.Units.gridUnit * 9
            implicitHeight: usage.implicitHeight
            ColumnLayout {
                id: usage
                anchors.verticalCenter: parent.verticalCenter
                visible: root.hasStats
                spacing: 1
                ResourceMeter { label: "CPU"; value: root.cpuPct; compact: false; maximum: root.cfg.resourceBarMax; warnAt: root.cfg.alertCpu }
                ResourceMeter { label: "RAM"; value: root.memPct; compact: false; maximum: root.cfg.resourceBarMax; warnAt: root.cfg.alertMem }
            }
        }

        // -------------------------------------------------------- actions --

        PlasmaComponents.BusyIndicator {
            visible: root.operation.busy
            running: visible
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
        }





        // The four action slots keep one width, so the columns to their left line up on every row.
        Item {
            Layout.alignment: root.detailLevel === 3 ? Qt.AlignTop : Qt.AlignVCenter
            Layout.preferredWidth: Kirigami.Units.gridUnit * 1.7 * 4 + Kirigami.Units.smallSpacing * 3
            implicitHeight: actionSlots.implicitHeight
            RowLayout {
                id: actionSlots
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Kirigami.Units.smallSpacing
                    ActionToolButton {
                        id: recoveryButton
                        opacity: root.hovered || root.highlighted || recoveryButton.activeFocus ? 1 : 0.55
                        visible: root.width > 480 && root.detailLevel !== 0 && root.detailLevel !== 3 && !root.backend.readOnly && (root.record.updateAvailable === true
                            || (root.record.isRunning && (root.record.health === "unhealthy" || root.record.state === "restarting")))
                        glyph: root.record.updateAvailable ? "package-upgrade" : "configure"
                        text: root.record.updateAvailable ? i18n("Update image…") : i18n("Recovery options: logs, restart or update")
                        onClicked: {
                            if (root.record.updateAvailable) root.dialogs.confirmUpdate(root.record)
                            else actions.popup(this, 0, height)
                        }
                    }
                    ActionToolButton {
                        id: toggleButton
                        opacity: root.hovered || root.highlighted || toggleButton.activeFocus ? 1 : 0.55
                        visible: root.detailLevel !== 0 && root.detailLevel !== 3
                        enabled: !root.backend.readOnly && !root.operation.busy
                        glyph: root.record.isRunning ? "media-playback-stop" : "media-playback-start"
                        text: root.record.state === "not-created" ? i18n("Create and start") : root.record.isRunning ? i18n("Stop") : i18n("Start")
                        onClicked: {
                            if (root.record.isRunning) {
                                root.backend.stopContainer(root.record)
                            } else {
                                root.backend.startContainer(root.record)
                            }
                        }
                    }
                    ActionToolButton {
                        id: webButton
                        opacity: root.hovered || root.highlighted || webButton.activeFocus ? 1 : 0.55
                        glyph: "insert-link"
                        text: i18n("Web links")
                        visible: root.width > 440 && root.detailLevel !== 0 && root.detailLevel !== 3 && root.record.isRunning && root.backend.linksFor(root.record).length > 0
                        onClicked: webActions.popup(webButton, 0, webButton.height)
                    }
                    ActionToolButton {
                        id: overflowButton
                        opacity: root.hovered || root.highlighted || overflowButton.activeFocus ? 1 : 0.55
                        Layout.alignment: root.detailLevel === 3 ? Qt.AlignTop : Qt.AlignVCenter
                        glyph: "application-menu"
                        text: i18n("More")
                        onClicked: actions.popup(overflowButton, 0, overflowButton.height)
                    }
            }
        }

        ContainerActions {
            id: webActions
            backend: root.backend
            record: root.record
            dialogs: root.dialogs
            browserOnly: true
        }
        ContainerActions {
            id: actions
            backend: root.backend
            record: root.record
            dialogs: root.dialogs
            onOpenDetail: function (recordId) { root.openDetail(recordId) }
            onOpenOutput: function (title, content, live, recordId) {
                root.openOutput(title, content, live, root.record.id)
            }
        }
    }

    onHoveredChanged: if(hovered) root.backend.previewContainer(root.containerKey,false)
    onClicked: {
        root.backend.previewContainer(root.containerKey,true)
        ListView.view.currentIndex = root.index
    }
    onDoubleClicked: root.openDetail(root.record.id)
    Keys.onReturnPressed: root.openDetail(root.record.id)
    Keys.onEnterPressed: root.openDetail(root.record.id)
    Accessible.name: root.name + ", " + Status.compactStatus(root.status, root.containerState, root.runningFor)

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: function (eventPoint) {
            actions.popup(root, eventPoint.position.x, eventPoint.position.y)
        }
    }
}
