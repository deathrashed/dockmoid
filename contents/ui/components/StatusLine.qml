import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/status.js" as Status

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
    /* Draw the spinner here while an action runs; list rows draw their own. */
    property bool showBusy: false
    /* Replaces the status text, for views that explain *why* (Needs attention). */
    property string labelOverride: ""

    readonly property string glyphName: Status.statusGlyph(root.attention, root.operationBusy, root.isRunning, root.glyphMode)
    readonly property string prefix: {
        switch (Status.prefixKey(root.attention)) {
        case "failed": return i18n("Failed") + " · "
        case "unhealthy": return i18n("Unhealthy") + " · "
        case "paused": return i18n("Paused") + " · "
        case "restarting": return i18n("Restarting") + " · "
        default: return ""
        }
    }
    readonly property string text: root.operationLabel !== "" ? root.operationLabel
        : root.labelOverride !== "" ? root.labelOverride
        : root.prefix + Status.compactStatus(root.status, root.containerState, root.runningFor)

    implicitWidth: line.implicitWidth
    implicitHeight: line.implicitHeight

    Tones { id: tones }

    RowLayout {
        id: line
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing / 2

        ActionIcon {
            visible: root.glyphName !== ""
            glyph: root.glyphName
            color: tones.color(Status.glyphTone(root.attention, root.isRunning))
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: implicitWidth
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
            text: root.text
            elide: Text.ElideRight
            font: Kirigami.Theme.smallFont
            color: tones.color(Status.statusTone(root.attention, root.operationLabel, root.operationOk, root.isRunning))
            HoverHandler { id: hover }
            PlasmaComponents.ToolTip {
                visible: hover.hovered
                text: (root.status !== "" ? root.status : root.containerState) + (root.operationLabel !== "" ? "\n" + root.operationLabel : "")
            }
        }
    }
}
