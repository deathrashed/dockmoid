pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/status.js" as Status
import "../../lib/style.js" as Style

/* ServicePreview — the selected (or hovered) container at a glance, with its main actions. */
Item {
    id: root
    objectName: "servicePreview"
    required property var backend
    signal openDetail(string recordId)
    readonly property var record: {const revision = backend.revision; return backend.findRecord(backend.previewRecordId)}
    readonly property string attention: root.record ? Status.attentionKind(root.record) : ""
    readonly property var spec: Status.badgeSpec(root.attention)
    readonly property bool running: root.record !== null && root.record.isRunning === true
    readonly property var links: root.record ? root.backend.linksFor(root.record) : []
    readonly property var can: backend.actionsFor(record)
    readonly property var stateCan: backend.stateActionsFor(record)
    readonly property var primary: backend.primaryActionFor(record)

    Tones { id: tones }

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 2
        visible: !root.record
        spacing: Kirigami.Units.smallSpacing
        ActionIcon {
            Layout.alignment: Qt.AlignHCenter
            glyph: "mouse-pointer-click"
            color: Style.HUE.sky
            implicitWidth: Kirigami.Units.iconSizes.large
            implicitHeight: implicitWidth
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: i18n("Nothing selected")
            font.bold: true
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: i18n("Select a container above to see its details here, with quick actions.")
            color: Kirigami.Theme.disabledTextColor
            font: Kirigami.Theme.smallFont
        }
    }

    Controls.ScrollView {
        id: scroll
        anchors.fill: parent
        visible: !!root.record
        contentWidth: availableWidth
        Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
        clip: true

        ColumnLayout {
            width: scroll.availableWidth
            spacing: Kirigami.Units.smallSpacing

            // ---- who
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                Layout.bottomMargin: 0
                spacing: Kirigami.Units.largeSpacing
                ServiceIcon {
                    visible: !!root.record
                    backend: root.backend
                    record: root.record || ({})
                    iconSize: Kirigami.Units.iconSizes.medium
                    tile: true
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 0
                    RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        PlasmaComponents.Label {
                            text: root.record ? root.record.name : ""
                            font.bold: true
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1
                            elide: Text.ElideRight
                            Layout.maximumWidth: scroll.availableWidth * 0.5
                        }
                        Pill {
                            visible: !!root.record
                            dense: true
                            tone: root.spec.tone
                            variant: root.spec.variant
                            glyph: root.spec.glyph
                            statusDot: root.spec.dot
                            text: root.spec.key === "running" ? i18n("Running") : root.spec.key === "unhealthy" ? i18n("Unhealthy")
                                : root.spec.key === "failed" ? i18n("Failed") : root.spec.key === "paused" ? i18n("Paused")
                                : root.spec.key === "restarting" ? i18n("Restarting") : root.spec.key === "not-created" ? i18n("Undeployed") : i18n("Stopped")
                        }
                        Pill {
                            visible: !!root.record && root.record.updateAvailable === true
                            dense: true
                            tone: "violet"
                            glyph: "cloud-download"
                            text: i18n("Update")
                        }
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: root.record ? root.record.image : ""
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                        elide: Text.ElideMiddle
                    }
                }
            }

            // ---- what you can do
            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing
                // The same rules as the menu and the list (lib/actions.js).
                DockButton {
                    visible: !!root.record && root.stateCan[root.primary.action] === true
                    blockedReason: root.backend.actionReason(root.record, root.primary.action)
                    variant: root.primary.action === "stop" ? "default" : "primary"
                    glyph: root.primary.action === "stop" ? "square" : "play"
                    text: root.primary.action === "create" ? i18n("Create and Start") : root.primary.action === "stop" ? i18n("Stop") : i18n("Start")
                    onClicked: root.backend.runAction(root.record, root.primary.action)
                }
                DockButton {
                    visible: root.stateCan.restart === true
                    blockedReason: root.backend.actionReason(root.record, "restart")
                    glyph: "rotate-cw"; text: i18n("Restart")
                    onClicked: root.backend.runAction(root.record, "restart")
                }
                DockButton {
                    visible: root.stateCan.resume === true
                    blockedReason: root.backend.actionReason(root.record, "resume")
                    glyph: "play"; text: i18n("Resume")
                    onClicked: root.backend.runAction(root.record, "resume")
                }
                DockButton {
                    visible: root.links.length > 0 && root.running
                    glyph: "globe"; text: i18n("Web")
                    onClicked: root.backend.openLink(root.links[0])
                }
                DockButton {
                    glyph: "badge-info"; text: i18n("Details")
                    onClicked: root.openDetail(root.record.id)
                }
            }

            // ---- the facts, and live usage beside them when there is room
            GridLayout {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                Layout.topMargin: Kirigami.Units.smallSpacing
                columns: width >= Kirigami.Units.gridUnit * 34 && root.running ? 2 : 1
                columnSpacing: Kirigami.Units.largeSpacing
                rowSpacing: Kirigami.Units.largeSpacing
                uniformCellWidths: true
                Card {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    padding: Kirigami.Units.smallSpacing
                    FieldRow { Layout.fillWidth: true; glyph: "activity"; label: i18n("Status"); value: root.record ? (root.record.state === "not-created" ? i18n("Undeployed") : (root.record.status || root.record.state)) : "" }
                    FieldRow { Layout.fillWidth: true; glyph: "heart-pulse"; label: i18n("Health"); value: root.record && root.record.health !== "none" ? String(root.record.health || "") : "" }
                    FieldRow { Layout.fillWidth: true; glyph: "folder-kanban"; label: i18n("Project"); value: root.record ? [root.record.project, root.record.service].filter(Boolean).join(" / ") : "" }
                    FieldRow { Layout.fillWidth: true; glyph: "plug"; label: i18n("Ports"); value: root.record ? String(root.record.ports || "").replace(/,\s*/g, "\n") : ""; wrap: true }
                    FieldRow { Layout.fillWidth: true; glyph: "network"; label: i18n("Networks"); value: root.record ? String(root.record.networks || "").replace(/,\s*/g, "\n") : ""; wrap: true }
                    FieldRow { Layout.fillWidth: true; glyph: "hard-drive"; label: i18n("Mounts"); value: root.record ? String(root.record.mounts || "").replace(/,\s*/g, "\n") : ""; wrap: true }
                }
                Card {
                    visible: root.running
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    padding: Kirigami.Units.smallSpacing * 2
                    title: i18n("Usage")
                    titleGlyph: "gauge"
                    titleTone: "cyan"
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.largeSpacing
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            spacing: 2
                            PlasmaComponents.Label { text: i18n("CPU %1", root.record ? root.record.cpu || "–" : ""); font: Kirigami.Theme.smallFont; color: Style.HUE.cyan }
                            Sparkline {
                                Layout.fillWidth: true
                                implicitHeight: Kirigami.Units.gridUnit * 2
                                samples: root.record && root.backend.revision >= 0 ? root.backend.historyFor(root.record.id).cpu : []
                                color: Style.HUE.cyan
                                floor: 10
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            spacing: 2
                            PlasmaComponents.Label { text: i18n("Memory %1", root.record ? root.record.mem || "–" : ""); font: Kirigami.Theme.smallFont; color: Style.HUE.fuchsia }
                            Sparkline {
                                Layout.fillWidth: true
                                implicitHeight: Kirigami.Units.gridUnit * 2
                                samples: root.record && root.backend.revision >= 0 ? root.backend.historyFor(root.record.id).mem : []
                                color: Style.HUE.fuchsia
                                floor: 10
                            }
                        }
                    }
                    FieldRow { Layout.fillWidth: true; label: i18n("Memory used"); value: root.record ? String(root.record.memU || "") : "" }
                    FieldRow { Layout.fillWidth: true; label: i18n("Net I/O"); value: root.record ? String(root.record.netio || "") : "" }
                    FieldRow { Layout.fillWidth: true; label: i18n("Processes"); value: root.record ? String(root.record.pids || "") : "" }
                }
            }
        }
    }
}
