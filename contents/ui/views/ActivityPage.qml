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
    /* True when shown inside the main page's dock. */
    property bool embedded: false
    signal openDetail(string recordId, int tab)
    /* A crash, restart or health change opens on Logs, where the cause usually is. */
    function open(entry) {
        if (!entry.id || !root.backend.findRecord(entry.id)) return
        root.backend.previewContainer(entry.id, true)
        root.openDetail(entry.id, ["crashed", "restarting", "unhealthy"].indexOf(entry.kind) >= 0 ? 1 : 0)
    }

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
            compact: root.embedded
            title: i18n("Activity")
            subtitle: root.backend.activity.length === 0 ? i18n("Nothing has changed since Dockmoid started")
                : i18np("%1 recent change", "%1 recent changes", root.backend.activity.length)
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
                // Only while the container still exists; a removed one has nothing to open.
                interactive: row.modelData.id !== "" && root.backend.revision >= 0 && !!root.backend.findRecord(row.modelData.id)
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
                        text: new Date(row.modelData.time).toDateString() === new Date().toDateString()
                            ? Qt.formatTime(new Date(row.modelData.time), "hh:mm:ss")
                            : Qt.formatDateTime(new Date(row.modelData.time), "MMM d hh:mm")
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                    }
                }
                HoverHandler { id: hover; cursorShape: row.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor }
                TapHandler { enabled: row.interactive; onTapped: root.open(row.modelData) }
                Components.Tip { text: row.interactive ? (["crashed", "restarting", "unhealthy"].indexOf(row.modelData.kind) >= 0 ? i18n("Open %1 on its logs", row.modelData.name) : i18n("Open %1", row.modelData.name)) : "" }
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
