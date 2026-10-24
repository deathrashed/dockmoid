pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../components" as Components
import "../../lib/status.js" as Status

/*
 * DiagnosePage — one container's trouble in one place: what the engine
 * reports (state, exit code, OOM, restarts, health), what happened lately
 * (Dockmoid alerts and engine events), the log lines worth reading first, and
 * the actions that fit. Observations are kept apart from explanations, and no
 * cause is guessed: an exit code's usual meaning is labelled as a convention.
 */
Item {
    id: root
    objectName: "diagnosePage"
    required property var backend
    required property var dialogs
    required property string recordId
    /* Inside Details the page's header and tabs are already there. */
    property bool embedded: false
    signal openDetail(string recordId, int tab)

    readonly property var record: { const revision = root.backend.revision; return root.backend.findRecord(root.recordId) }
    property var facts: null
    /* The inspect read answered (with facts, or with nothing). */
    property bool factsRead: false
    /* lib/status.js healthState: the key DockerBackend.healthWords words, as on Inspector · Health. */
    readonly property var health: Status.healthState(root.facts, root.record, root.factsRead)
    property string events: ""
    property string logs: ""
    property var digest: null
    property bool loading: false
    readonly property var alerts: root.record ? (root.backend.activity || []).filter(function (a) { return a.id === root.record.id }).slice(0, 12) : []
    readonly property var can: { const revision = root.backend.operationsRevision; return root.record ? root.backend.actionsFor(root.record) : ({}) }

    function load() {
        const rec = root.record
        root.loading = !!rec && rec.state !== "not-created"
        root.backend.readTrouble(rec, "diagnose", function (r) {
            if (r.factsRead) { root.facts = r.facts; root.factsRead = true }
            if (r.logsRead) { root.logs = r.logs; root.digest = r.digest; root.loading = false }
        })
        if (!root.loading) return
        const id = rec.id
        root.backend.diagnose(rec, "events", "", undefined, function (text) { if (root.recordId === id) root.events = text })
    }
    Component.onCompleted: load()
    onRecordIdChanged: load()

    function exitText(code, oom) { return root.backend.exitWords(code, oom) }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Components.PageHeader {
            visible: !root.embedded
            title: root.record ? i18n("Diagnose %1", root.record.name) : i18n("Container is gone")
            subtitle: i18n("What the engine reports, what happened lately, and what can be done")
            Components.DockButton { glyph: "view-refresh"; text: i18n("Reload"); enabled: !root.loading; onClicked: root.load() }
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
                    title: i18n("What the Engine Reports")
                    titleGlyph: "stethoscope"
                    titleTone: "blue"
                    Components.FieldRow { Layout.fillWidth: true; glyph: "activity"; label: i18n("State"); value: root.record ? root.record.status || root.record.state : "" }
                    Components.FieldRow {
                        Layout.fillWidth: true; glyph: "circle-x"; label: i18n("Last exit"); wrap: true
                        glyphTone: root.facts && (root.facts.exitCode > 0 || root.facts.oomKilled) ? "bad" : "muted"
                        value: root.facts && root.facts.finishedAt > 0 ? root.exitText(root.facts.exitCode, root.facts.oomKilled) : ""
                    }
                    Components.FieldRow { Layout.fillWidth: true; glyph: "message-square-warning"; label: i18n("Engine error"); wrap: true; glyphTone: "bad"; value: root.facts ? root.facts.error : "" }
                    Components.FieldRow {
                        Layout.fillWidth: true; glyph: "rotate-cw"; label: i18n("Restarts")
                        glyphTone: root.facts && root.facts.restarts > 0 ? "warn" : "muted"
                        value: root.facts ? i18np("%1 since created", "%1 since created", root.facts.restarts) : ""
                    }
                    Components.FieldRow {
                        Layout.fillWidth: true; glyph: "heart-pulse"; label: i18n("Health"); wrap: true
                        glyphTone: root.health.tone
                        value: root.backend.healthWords(root.health)
                            + (root.facts && root.facts.health && root.facts.health.lastOutput !== "" ? "\n" + root.facts.health.lastOutput.split("\n").slice(-2).join("\n") : "")
                    }
                    Components.FieldRow {
                        Layout.fillWidth: true; glyph: "memory-stick"; label: i18n("Memory limit")
                        value: root.facts && root.facts.memoryLimit > 0 ? (root.facts.memoryLimit / 1048576).toFixed(0) + " MiB" : ""
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        Layout.margins: Kirigami.Units.smallSpacing
                        wrapMode: Text.WordWrap
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                        text: i18n("Exit codes follow common conventions; an application may use them differently. These are observations, not a diagnosis.")
                    }
                }

                Components.Card {
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.smallSpacing
                    prominentTitle: true
                    title: i18n("What the Logs Show")
                    titleGlyph: "scroll-text"
                    titleTone: "amber"
                    titleHint: root.digest && root.digest.errors > 0 ? String(root.digest.errors) : ""
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        Layout.margins: Kirigami.Units.smallSpacing
                        visible: root.loading
                        text: i18n("Reading the last 300 lines…")
                    }
                    Components.LogDigest {
                        Layout.fillWidth: true
                        Layout.margins: Kirigami.Units.smallSpacing
                        visible: !root.loading
                        digest: root.digest
                    }
                    Components.DockButton { Layout.margins: Kirigami.Units.smallSpacing; glyph: "scroll-text"; text: i18n("Full Logs"); visible: !!root.record; onClicked: root.openDetail(root.record.id, 1) }
                }

                Components.Card {
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.smallSpacing
                    prominentTitle: true
                    title: i18n("What Happened Lately")
                    titleGlyph: "clock"
                    titleTone: "slate"
                    Repeater {
                        model: root.alerts
                        delegate: PlasmaComponents.Label {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.leftMargin: Kirigami.Units.smallSpacing
                            text: Qt.formatDateTime(new Date(modelData.time), "MMM d hh:mm") + "  " + modelData.text
                            wrapMode: Text.Wrap
                        }
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        Layout.margins: Kirigami.Units.smallSpacing
                        text: root.events || i18n("Loading…")
                        wrapMode: Text.Wrap
                        font.family: Kirigami.Theme.fixedWidthFont.family
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        textFormat: Text.PlainText
                    }
                }

                // Only actions the shared rules allow, each one reviewed by its own confirmation.
                Components.Card {
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.smallSpacing
                    prominentTitle: true
                    title: i18n("Possible Next Steps")
                    titleGlyph: "list-checks"
                    titleTone: "green"
                    Flow {
                        Layout.fillWidth: true
                        Layout.margins: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing
                        Components.DockButton { visible: root.can.start === true; glyph: "media-playback-start"; text: i18n("Start"); onClicked: root.backend.runAction(root.record, "start") }
                        Components.DockButton { visible: root.can.restart === true; glyph: "view-refresh"; text: i18n("Restart"); onClicked: root.backend.runAction(root.record, "restart") }
                        Components.DockButton { visible: root.can.resume === true; glyph: "media-playback-start"; text: i18n("Resume"); onClicked: root.backend.runAction(root.record, "resume") }
                        Components.DockButton { visible: root.can.update === true && root.record.updateAvailable === true; glyph: "cloud-download"; text: i18n("Update…"); onClicked: root.dialogs.confirmUpdate(root.record) }
                        Components.DockButton { visible: !!root.record && root.record.composeFiles !== "" && !root.backend.remoteEngine; glyph: "document-edit"; text: i18n("Edit Compose File"); onClicked: root.backend.editCompose(root.record) }
                        Components.DockButton { visible: !!root.record; glyph: "badge-info"; text: i18n("Details"); onClicked: root.openDetail(root.record.id, 0) }
                    }
                }
            }
        }
    }
}
