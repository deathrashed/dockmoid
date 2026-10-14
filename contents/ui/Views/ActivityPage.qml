pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../components" as Components

/* ActivityPage — what changed lately: crashes, restarts, health changes, starts and stops. */
Item {
    id: root
    objectName: "activityPage"
    required property var backend
    signal openDetail(string recordId)

    readonly property var kinds: ({
        crashed: {glyph: "circle-x", tone: "bad"},
        restarting: {glyph: "rotate-cw", tone: "warn"},
        unhealthy: {glyph: "heart-pulse", tone: "bad"},
        recovered: {glyph: "circle-check", tone: "ok"},
        started: {glyph: "play", tone: "ok"},
        stopped: {glyph: "square", tone: "muted"}
    })

    Components.Tones { id: tones }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Components.PageHeader {
            title: i18n("Activity")
            subtitle: root.backend.activity.length === 0 ? i18n("Nothing has changed since Dockmoid started")
                : i18np("%1 recent change", "%1 recent changes", root.backend.activity.length)
            leading: Components.ActionIcon { glyph: "bell-ring"; color: Kirigami.Theme.highlightColor; implicitWidth: Kirigami.Units.iconSizes.medium; implicitHeight: implicitWidth }
            Components.DockButton {
                glyph: "trash"
                text: i18n("Clear")
                enabled: root.backend.activity.length > 0
                onClicked: root.backend.activity = []
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Kirigami.Units.smallSpacing
            clip: true
            spacing: Kirigami.Units.smallSpacing
            model: root.backend.activity
            boundsBehavior: Flickable.StopAtBounds

            delegate: Components.Card {
                id: row
                required property var modelData
                readonly property var look: root.kinds[row.modelData.kind] || ({glyph: "info", tone: "muted"})
                width: ListView.view.width
                padding: Kirigami.Units.smallSpacing * 1.5
                interactive: row.modelData.id !== ""
                hovered: hover.hovered
                tone: row.look.tone === "muted" ? "" : row.look.tone

                RowLayout {
                    spacing: Kirigami.Units.largeSpacing
                    Components.ActionIcon {
                        glyph: row.look.glyph
                        color: tones.color(row.look.tone)
                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                        implicitHeight: implicitWidth
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: row.modelData.text
                        elide: Text.ElideRight
                    }
                    PlasmaComponents.Label {
                        text: Qt.formatDateTime(new Date(row.modelData.time), "hh:mm:ss")
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                    }
                }
                HoverHandler { id: hover; cursorShape: row.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor }
                TapHandler { enabled: row.interactive; onTapped: root.openDetail(row.modelData.id) }
            }

            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.gridUnit * 2
                visible: list.count === 0
                icon.name: "notifications"
                text: i18n("No activity yet")
                explanation: i18n("Crashes, restarts, health changes, starts and stops appear here while Dockmoid is running.")
            }
        }
    }
}
