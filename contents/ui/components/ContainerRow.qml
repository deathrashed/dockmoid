import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

/*
 * ContainerRow — one container, rendered at one of four detail levels.
 *
 *   0 minimal   name
 *   1 normal    + state and status
 *   2 detailed  + image, cpu/memory, published ports
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
    readonly property var record: ({
        "id": root.containerKey,
        "containerKey": root.containerKey,
        "name": root.name,
        "image": root.image,
        "runningFor": root.runningFor,
        "state": root.containerState,
        "status": root.status,
        "health": root.health,
        "isRunning": root.isRunning,
        "localVolumes": root.localVolumes,
        "networks": root.networks,
        "size": root.size,
        "platform": root.platform,
        "project": root.project,
        "service": root.service,
        "cpu": root.cpu,
        "mem": root.mem,
        "blockio": root.blockio,
        "netio": root.netio,
        "pids": root.pids,
        "cpuPct": root.cpuPct,
        "memPct": root.memPct,
        "ports": root.ports,
        "composeFiles": root.composeFiles,
        "composeWorkDir": root.composeWorkDir
    })

    signal openDetail(string recordId)
    signal openOutput(string title, string content, bool live, string recordId)

    readonly property var cfg: plasmoid.configuration
    readonly property bool hasStats: root.isRunning && root.cpu !== ""

    /* 0 means "follow the panel scale"; anything else is a pixel override. */
    readonly property int iconSize: cfg.rowIconSize > 0
        ? cfg.rowIconSize
        : Kirigami.Units.iconSizes.small
    readonly property var links: backend.linksFor(root.record)

    implicitHeight: layout.implicitHeight + Kirigami.Units.smallSpacing * 2
    width: ListView.view ? ListView.view.width : implicitWidth
    highlighted: ListView.isCurrentItem

    // --------------------------------------------------------- content ---

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        StateDot {
            containerState: root.record.state
            health: root.cfg.showHealth ? root.record.health : "none"
            showHealth: root.cfg.showHealth
        }

        /*
         * The user's own provider artwork is drawn in full colour (isMask off),
         * because those SVGs carry real brand colours that a mask would throw
         * away. The bundled glyphs are flat silhouettes, so they stay masked and
         * follow the theme.
         */
        Kirigami.Icon {
            id: serviceIcon
            readonly property bool hasIcon: root.backend.serviceIconUrl(root.record.image, root.record.name) !== ""
            visible: hasIcon
            source: root.backend.serviceIconUrl(root.record.image, root.record.name)
            isMask: !root.backend.serviceIconIsColored(root.record.image, root.record.name)
            implicitWidth: root.iconSize
            implicitHeight: implicitWidth
            color: Kirigami.Theme.colorSet
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            // -- name -------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: root.record.name
                    font.bold: true
                    elide: Text.ElideRight
                }

                PlasmaComponents.Label {
                    visible: root.record.health === "unhealthy" && root.cfg.showHealth
                    text: i18n("unhealthy")
                    color: Kirigami.Theme.negativeTextColor
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }

                PlasmaComponents.Label {
                    visible: root.record.health === "starting" && root.cfg.showHealth
                    text: i18n("starting")
                    color: Kirigami.Theme.highlightColor
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }
            }

            // -- state / status (level >= 1) --------------------------
            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: root.detailLevel >= 1
                text: root.record.status !== "" ? root.record.status : root.record.state
                elide: Text.ElideRight
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                color: root.record.isRunning
                    ? Kirigami.Theme.textColor
                    : Kirigami.Theme.disabledTextColor
            }

            // -- image + usage (level >= 2) ---------------------------
            RowLayout {
                Layout.fillWidth: true
                visible: root.detailLevel >= 2
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: root.record.image
                    elide: Text.ElideRight
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    color: Kirigami.Theme.disabledTextColor
                }

                // CPU
                PlasmaComponents.Label {
                    visible: root.hasStats
                    text: "CPU " + root.record.cpu
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                }

                MiniBar {
                    visible: root.hasStats && root.cfg.showResourceBars
                    value: root.record.cpuPct
                    barColor: Kirigami.Theme.positiveTextColor
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2.5
                }

                // Memory
                PlasmaComponents.Label {
                    visible: root.hasStats
                    text: "MEM " + root.record.mem
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                }

                MiniBar {
                    visible: root.hasStats && root.cfg.showResourceBars
                    value: root.record.memPct
                    barColor: Kirigami.Theme.highlightColor
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2.5
                }
            }

            // -- ports (level >= 2) ----------------------------------
            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: root.detailLevel >= 2 && root.links.length > 0
                text: i18n("Open: %1", root.links.map(function (l) {
                    return ":" + l.port + " (" + l.label + ")"
                }).join("  "))
                elide: Text.ElideRight
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                color: Kirigami.Theme.highlightColor
            }

            // -- everything else (level 3) ---------------------------
            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: root.detailLevel >= 3
                text: i18n("ID: %1", root.record.id)
                elide: Text.ElideMiddle
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                color: Kirigami.Theme.disabledTextColor
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: root.detailLevel >= 3 && root.record.project !== ""
                text: i18n("Project: %1%2", root.record.project,
                           root.record.service !== ""
                               ? i18n(" · %1", root.record.service)
                               : "")
                elide: Text.ElideRight
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                color: Kirigami.Theme.disabledTextColor
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: root.detailLevel >= 3 && root.record.networks !== ""
                text: i18n("Networks: %1 · Volumes: %2", root.record.networks, root.record.localVolumes)
                elide: Text.ElideRight
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                color: Kirigami.Theme.disabledTextColor
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: root.detailLevel >= 3 && root.hasStats
                text: i18n("Net I/O: %1 · Block I/O: %2 · PIDs: %3",
                           root.record.netio, root.record.blockio, root.record.pids)
                elide: Text.ElideRight
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                color: Kirigami.Theme.disabledTextColor
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: root.detailLevel >= 3
                text: i18n("Uptime: %1 · Size: %2 · Platform: %3",
                           root.record.runningFor, root.record.size,
                           root.record.platform !== "" ? root.record.platform : "—")
                elide: Text.ElideRight
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                color: Kirigami.Theme.disabledTextColor
            }
        }

        // -------------------------------------------------------- actions --

        PlasmaComponents.ToolButton {
            id: toggleButton
            display: PlasmaComponents.AbstractButton.IconOnly
            icon.name: root.record.isRunning ? "media-playback-stop" : "media-playback-start"
            text: root.record.isRunning ? i18n("Stop") : i18n("Start")
            onClicked: {
                if (root.record.isRunning) {
                    root.backend.stopContainer(root.record)
                } else {
                    root.backend.startContainer(root.record)
                }
            }
            PlasmaComponents.ToolTip { text: toggleButton.text }
        }

        PlasmaComponents.ToolButton {
            id: webButton
            display: PlasmaComponents.AbstractButton.IconOnly
            icon.source: "file:///home/rd/.local/share/icons/Papirus/24x24/actions/map-globe.svg"
            text: i18n("Web links")
            visible: root.record.isRunning && root.backend.linksFor(root.record).length > 0
            onClicked: webActions.popup(webButton, 0, webButton.height)
            PlasmaComponents.ToolTip { text: webButton.text }
        }

        ContainerActions {
            id: webActions
            backend: root.backend
            record: root.record
            dialogs: root.dialogs
            browserOnly: true
        }

        PlasmaComponents.ToolButton {
            id: overflowButton
            display: PlasmaComponents.AbstractButton.IconOnly
            icon.name: "application-menu"
            text: i18n("More")
            onClicked: actions.popup(overflowButton, 0, overflowButton.height)
            PlasmaComponents.ToolTip { text: overflowButton.text }
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

    onClicked: {
        ListView.view.currentIndex = index
    }
    onDoubleClicked: root.openDetail(root.record.id)

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: function (eventPoint) {
            actions.popup(root, eventPoint.position.x, eventPoint.position.y)
        }
    }
}
