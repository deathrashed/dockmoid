import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../components" as Components
import "../../lib/status.js" as Status

/*
 * Inspector · Health — the selected container's health: its healthcheck, its
 * last exit and restarts, its probe, what its logs keep repeating, its recent
 * events, and the fixes that apply to it. Reads only what the widget already
 * has, plus one inspect read when the selection changes.
 */
Item {
    id: root
    required property var backend
    signal openDetail(string recordId, int tab)

    readonly property var record: { const revision = root.backend.revision; return root.backend.findRecord(root.backend.previewRecordId) }
    property var facts: null
    /* The inspect read answered (with facts, or with nothing). */
    property bool factsRead: false
    property var digest: null
    property string shownId: ""
    readonly property var events: {
        const rec = root.record
        if (!rec) return []
        return (root.backend.activity || []).filter(function (a) { return a.id === rec.id }).slice(0, 12)
    }
    readonly property var can: { const revision = root.backend.operationsRevision; return root.record ? root.backend.actionsFor(root.record) : ({}) }
    readonly property var logDigest: root.digest ? root.digest : (root.record && root.backend.logIssues[root.record.id] ? root.backend.logIssues[root.record.id] : null)

    function load() {
        const rec = root.record
        root.facts = null; root.digest = null; root.factsRead = false
        if (!rec || rec.state === "not-created") return
        const id = rec.id
        root.backend.fetchFacts(rec, function (f) { if (root.record && root.record.id === id) { root.facts = f; root.factsRead = true } })
        root.backend.tailLogs(rec, 300, function (text) { if (root.record && root.record.id === id) root.digest = Status.digestLogs(text) })
    }
    onRecordChanged: { const id = root.record ? root.record.id : ""; if (id !== root.shownId) { root.shownId = id; root.load() } }
    Component.onCompleted: { root.shownId = root.record ? root.record.id : ""; root.load() }

    function healthLine() {
        const h = root.facts ? root.facts.health : null
        if (!root.record || root.record.state === "not-created") return i18n("Not deployed yet")
        if (!root.facts) return root.record.health && root.record.health !== "none" ? root.record.health
            : root.factsRead ? i18n("Unknown: the engine did not describe this container") : i18n("Reading…")
        if (!h) return root.facts && root.facts.healthCheck === "" ? i18n("No healthcheck is configured for this container") : i18n("No healthcheck result")
        if (h.status === "healthy") return i18n("Healthy")
        if (h.status === "starting") return i18n("Starting: waiting for the first passing check")
        if (h.status === "unhealthy") return h.failingStreak > 0 ? i18np("Unhealthy: %1 failed check in a row", "Unhealthy: %1 failed checks in a row", h.failingStreak) : i18n("Unhealthy")
        return h.status
    }
    function healthTone() {
        const h = root.facts ? root.facts.health : null
        const status = h ? h.status : (root.record ? root.record.health : "")
        return status === "healthy" ? "ok" : status === "unhealthy" ? "bad" : status === "starting" ? "warn" : "muted"
    }

    Controls.ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true
        ColumnLayout {
            width: parent.width
            spacing: Kirigami.Units.smallSpacing

            InspectorHeader {
                Layout.fillWidth: true
                backend: root.backend
                record: root.record
                Components.DockButton {
                    glyph: "view-refresh"; text: i18n("Reload")
                    enabled: !!root.record
                    onClicked: root.load()
                }
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                visible: !root.record
                wrapMode: Text.WordWrap
                color: Kirigami.Theme.disabledTextColor
                text: i18n("Select a container to see its health.")
            }

            Components.Card {
                visible: !!root.record
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.smallSpacing
                prominentTitle: true
                title: i18n("Health")
                titleGlyph: "heart-pulse"
                titleTone: root.healthTone() === "bad" ? "bad" : "slate"
                Components.FieldRow {
                    Layout.fillWidth: true; glyph: "heart-pulse"; label: i18n("Healthcheck"); wrap: true
                    glyphTone: root.healthTone(); value: root.healthLine()
                }
                Components.FieldRow {
                    Layout.fillWidth: true; glyph: "stethoscope"; label: i18n("Last check"); wrap: true
                    visible: !!root.facts && !!root.facts.health && root.facts.health.lastAt > 0
                    glyphTone: root.facts && root.facts.health && root.facts.health.lastExit > 0 ? "bad" : "muted"
                    value: root.facts && root.facts.health
                        ? (root.facts.health.lastExit === 0 ? i18n("Passed") : i18n("Failed (exit %1)", root.facts.health.lastExit))
                          + (root.facts.health.lastOutput !== "" ? "\n" + root.facts.health.lastOutput.split("\n").slice(-2).join("\n") : "")
                        : ""
                }
                Components.FieldRow {
                    Layout.fillWidth: true; glyph: "rotate-cw"; label: i18n("Restarts")
                    glyphTone: root.facts && root.facts.restarts > 0 ? "warn" : "muted"
                    value: root.facts ? i18np("%1 since it was created", "%1 since it was created", root.facts.restarts) : ""
                }
                Components.FieldRow {
                    Layout.fillWidth: true; glyph: "circle-x"; label: i18n("Last exit"); wrap: true
                    glyphTone: root.facts && (root.facts.exitCode > 0 || root.facts.oomKilled) ? "bad" : "muted"
                    value: root.facts && root.facts.finishedAt > 0 ? root.backend.exitWords(root.facts.exitCode, root.facts.oomKilled) : ""
                }
                Components.FieldRow {
                    visible: !!root.record && root.record.probe !== undefined && root.record.probe !== ""
                    Layout.fillWidth: true; glyph: "globe"; label: i18n("Web page")
                    glyphTone: root.record && root.record.probe === "up" ? "ok" : "bad"
                    value: root.record && root.record.probe === "up" ? i18n("Answers") : i18n("Does not answer")
                }
            }

            Components.Card {
                visible: !!root.record && root.record.state !== "not-created"
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.smallSpacing
                prominentTitle: true
                title: i18n("What the Logs Show")
                titleGlyph: "scroll-text"
                titleTone: "amber"
                Components.LogDigest {
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.smallSpacing
                    digest: root.logDigest
                }
            }

            Components.Card {
                visible: !!root.record
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.smallSpacing
                prominentTitle: true
                title: i18n("Recent Events")
                titleGlyph: "bell-ring"
                titleTone: "slate"
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    visible: root.events.length === 0
                    wrapMode: Text.WordWrap
                    color: Kirigami.Theme.disabledTextColor
                    text: i18n("Nothing recorded for this container since Dockmoid started.")
                }
                Repeater {
                    model: root.events
                    delegate: PlasmaComponents.Label {
                        required property var modelData
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: Qt.formatDateTime(new Date(modelData.time), "MMM d hh:mm") + "  " + modelData.text
                    }
                }
            }

            // The fixes that apply to this container, only the ones allowed now.
            Flow {
                visible: !!root.record
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing
                Components.DockButton { glyph: "stethoscope"; text: i18n("Diagnose"); onClicked: root.backend.diagnoseRequested(root.record.id) }
                Components.DockButton { visible: root.can.restart === true; glyph: "view-refresh"; text: i18n("Restart"); onClicked: root.backend.runAction(root.record, "restart") }
                Components.DockButton { visible: root.can.stop === true && root.record.isRunning; glyph: "square"; text: i18n("Stop"); onClicked: root.backend.runAction(root.record, "stop") }
                Components.DockButton { glyph: "scroll-text"; text: i18n("Logs"); onClicked: root.openDetail(root.record.id, 1) }
                Components.DockButton { glyph: "badge-info"; text: i18n("Details"); onClicked: root.openDetail(root.record.id, 0) }
            }
        }
    }
}
