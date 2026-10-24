import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/status.js" as Status
import "../../lib/style.js" as Style

/*
 * StatusLine — the small "state · time" line under a container's name.
 *
 * One component for every view, so colour, wording and glyph follow the same
 * rules everywhere. The rules live in lib/status.js (tested); this file only
 * turns their keys into colours and translated words.
 *
 *   glyphMode "always"     a glyph for every state (list rows)
 *             "attention"  a glyph only when something needs a look
 *             "none"       text only
 */
Item {
    id: root

    property string status: ""
    property string containerState: ""
    property string runningFor: ""
    property bool isRunning: false
    property string attention: ""
    property string operationLabel: ""
    property bool operationOk: true
    property bool operationBusy: false
    property string glyphMode: "always"
    /* Show the state as a badge, then the elapsed time. */
    property bool badge: false
    /* Draw the spinner here while an action runs; list rows draw their own. */
    property bool showBusy: false
    /* Replaces the status text, for views that explain *why* (Needs attention). */
    property string labelOverride: ""
    /* Glyph or badge only: for rows whose timeline already gives the times. */
    property bool showText: true

    readonly property string glyphName: root.showBadge ? "" : Status.statusGlyph(root.attention, root.operationBusy, root.isRunning, root.badge ? "always" : root.glyphMode)
    readonly property var spec: Status.badgeSpec(root.attention)
    readonly property bool showBadge: root.badge && Status.isProblem(root.attention) && root.operationLabel === "" && root.labelOverride === ""
    readonly property string badgeWord: {
        switch (root.spec.key) {
        case "running": return i18n("Running")
        case "unhealthy": return i18n("Unhealthy")
        case "failed": return i18n("Failed")
        case "paused": return i18n("Paused")
        case "restarting": return i18n("Restarting")
        case "not-created": return i18n("Undeployed")
        default: return i18n("Stopped")
        }
    }
    readonly property string prefix: {
        switch (Status.prefixKey(root.attention)) {
        case "failed": return i18n("Failed") + " · "
        case "unhealthy": return i18n("Unhealthy") + " · "
        case "paused": return i18n("Paused") + " · "
        case "restarting": return i18n("Restarting") + " · "
        default: return ""
        }
    }
    readonly property string elapsed: Status.compactStatus(root.status, root.containerState, root.runningFor)
    readonly property string text: root.operationLabel !== "" ? root.operationLabel
        : root.labelOverride !== "" ? root.labelOverride
        : root.showBadge ? root.elapsed
        : root.prefix + root.elapsed

    /* A tone name or hue to a colour; cheaper than an item per instance. */
    function toneColor(name) {
        switch (name) {
        case "ok": return Kirigami.Theme.positiveTextColor
        case "bad": return Kirigami.Theme.negativeTextColor
        case "warn": return Kirigami.Theme.neutralTextColor
        case "info": return Kirigami.Theme.highlightColor
        case "muted": return Kirigami.Theme.disabledTextColor
        case "text": return Kirigami.Theme.textColor
        default: return Style.HUE[name] !== undefined ? Style.HUE[name] : Kirigami.Theme.textColor
        }
    }

    implicitWidth: line.implicitWidth
    implicitHeight: line.implicitHeight

    RowLayout {
        id: line
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing / 2

        ActionIcon {
            visible: root.glyphName !== ""
            glyph: root.glyphName
            color: root.toneColor(Status.glyphTone(root.attention, root.isRunning))
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: implicitWidth
        }
        Pill {
            visible: root.showBadge
            dense: true
            text: root.badgeWord
            tone: root.spec.tone
            variant: root.spec.variant
            glyph: root.spec.glyph
            statusDot: root.spec.dot
        }
        PlasmaComponents.BusyIndicator {
            visible: root.showBusy && root.operationBusy
            running: visible
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            visible: root.showText && root.text !== ""
            text: root.text
            elide: Text.ElideRight
            font: Kirigami.Theme.smallFont
            color: root.toneColor(Status.statusTone(root.attention, root.operationLabel, root.operationOk, root.isRunning))
            Tip { text: (root.status !== "" ? root.status : root.containerState) + (root.operationLabel !== "" ? "\n" + root.operationLabel : "") }
        }
    }
}
