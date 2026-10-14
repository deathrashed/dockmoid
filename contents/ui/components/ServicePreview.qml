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
                    tileColor: tones.color(Status.glyphTone(root.attention, root.running))
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
                                : root.spec.key === "restarting" ? i18n("Restarting") : root.spec.key === "not-created" ? i18n("Not created") : i18n("Stopped")
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
                DockButton {
                    visible: !!root.record && !root.backend.readOnly
                    variant: root.running ? "default" : "primary"
                    glyph: root.running ? "square" : "play"
                    iconTone: root.running ? "rose" : ""
                    text: root.record && root.record.state === "not-created" ? i18n("Create and start") : root.running ? i18n("Stop") : i18n("Start")
                    onClicked: root.running ? root.backend.stopContainer(root.record) : root.backend.startContainer(root.record)
                }
                DockButton {
                    visible: root.running && !root.backend.readOnly
                    glyph: "rotate-cw"; iconTone: "emerald"; text: i18n("Restart")
                    onClicked: root.backend.restartContainer(root.record)
                }
                DockButton {
                    visible: root.links.length > 0 && root.running
                    glyph: "globe"; iconTone: "sky"; text: i18n("Open web UI")
                    onClicked: root.backend.openLink(root.links[0])
                }
                DockButton {
                    glyph: "badge-info"; iconTone: "indigo"; text: i18n("Details")
                    onClicked: root.openDetail(root.record.id)
                }
            }

            // ---- the facts
            Card {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                Layout.topMargin: Kirigami.Units.smallSpacing
                padding: Kirigami.Units.smallSpacing
                FieldRow { Layout.fillWidth: true; glyph: "activity"; glyphTone: "emerald"; label: i18n("Status"); value: root.record ? (root.record.state === "not-created" ? i18n("Not created") : (root.record.status || root.record.state)) : "" }
                FieldRow { Layout.fillWidth: true; glyph: "folder-kanban"; glyphTone: "yellow"; label: i18n("Project"); value: root.record ? [root.record.project, root.record.service].filter(Boolean).join(" / ") : "" }
                FieldRow { Layout.fillWidth: true; glyph: "plug"; glyphTone: "teal"; label: i18n("Ports"); value: root.record ? String(root.record.ports || "") : ""; wrap: true }
                FieldRow { Layout.fillWidth: true; glyph: "hard-drive"; glyphTone: "orange"; label: i18n("Mounts"); value: root.record ? String(root.record.mounts || "") : ""; wrap: true }
                FieldRow { Layout.fillWidth: true; glyph: "gauge"; glyphTone: "fuchsia"; label: i18n("CPU / RAM"); value: root.record ? [root.record.cpu, root.record.mem].filter(Boolean).join(" / ") : "" }
            }
        }
    }
}
