pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../components" as Components

/*
 * Inspector · Events — what happened to the selected container: Dockmoid's own
 * alerts (crashes, health changes, actions) and the engine's event log for the
 * last day.
 */
Item {
    id: root
    required property var backend

    readonly property var record: { const revision = backend.revision; return backend.findRecord(backend.previewRecordId) }
    readonly property var alerts: {
        const rec = root.record
        if (!rec) return []
        return (root.backend.activity || []).filter(function (a) { return a.id === rec.id || a.name === rec.name }).slice(0, 50)
    }
    property string engineEvents: ""
    property string shownKey: ""

    function refresh() {
        const rec = root.record
        if (!rec || rec.state === "not-created") { root.engineEvents = ""; return }
        const id = rec.id
        root.engineEvents = i18n("Loading…")
        root.backend.diagnose(rec, "events", "", undefined, function (text) { if (root.record && root.record.id === id) root.engineEvents = text })
    }
    // Re-read when the selection or the container's state changes.
    readonly property string key: record ? record.id + "|" + record.state : ""
    onKeyChanged: if (key !== shownKey) { shownKey = key; refresh() }

    InspectorEmpty { anchors.fill: parent; visible: !root.record; text: i18n("Select a container to see what happened to it.") }

    ColumnLayout {
        anchors.fill: parent
        visible: !!root.record
        spacing: 0
        InspectorHeader {
            Layout.fillWidth: true
            backend: root.backend
            record: root.record
            Components.ActionToolButton { glyph: "view-refresh"; text: i18n("Reload events"); onClicked: root.refresh() }
        }
        Controls.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            ColumnLayout {
                width: parent.width
                spacing: Kirigami.Units.smallSpacing
                Components.Card {
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.smallSpacing
                    prominentTitle: true
                    title: i18n("Alerts")
                    titleGlyph: "bell-ring"
                    titleTone: "amber"
                    titleHint: root.alerts.length > 0 ? String(root.alerts.length) : ""
                    PlasmaComponents.Label {
                        visible: root.alerts.length === 0
                        Layout.fillWidth: true
                        Layout.margins: Kirigami.Units.smallSpacing
                        text: i18n("No crashes, health changes or actions recorded since Dockmoid started.")
                        wrapMode: Text.Wrap
                        color: Kirigami.Theme.disabledTextColor
                    }
                    Repeater {
                        model: root.alerts
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.leftMargin: Kirigami.Units.smallSpacing
                            Layout.rightMargin: Kirigami.Units.smallSpacing
                            PlasmaComponents.Label {
                                text: new Date(modelData.time).toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
                                font: Kirigami.Theme.smallFont
                                color: Kirigami.Theme.disabledTextColor
                            }
                            PlasmaComponents.Label { Layout.fillWidth: true; text: modelData.text; wrapMode: Text.Wrap }
                        }
                    }
                }
                Components.Card {
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.smallSpacing
                    prominentTitle: true
                    title: i18n("Engine Events · Last 24 Hours")
                    titleGlyph: "clock"
                    titleTone: "slate"
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        Layout.margins: Kirigami.Units.smallSpacing
                        text: root.engineEvents || i18n("This service has no container yet.")
                        wrapMode: Text.Wrap
                        font.family: Kirigami.Theme.fixedWidthFont.family
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        textFormat: Text.PlainText
                    }
                }
            }
        }
    }
}
