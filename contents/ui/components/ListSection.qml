import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/style.js" as Style

/* ListSection — the heading above a run of containers that share a state. */
Item {
    id: root
    /* "pinned", "attention", "running", "stopped" or "not-created". */
    property string group: ""
    property int count: 0

    readonly property var looks: ({
        "pinned": {label: i18n("Pinned"), glyph: "pin", tone: "yellow"},
        "attention": {label: i18n("Needs attention"), glyph: "triangle-alert", tone: "rose"},
        "running": {label: i18n("Running"), glyph: "circle-play", tone: "emerald"},
        "stopped": {label: i18n("Stopped"), glyph: "circle-pause", tone: "slate"},
        "not-created": {label: i18n("Not created"), glyph: "package-plus", tone: "sky"}
    })
    readonly property var look: root.looks[root.group] || ({label: root.group, glyph: "layers", tone: "muted"})
    readonly property font headingFont: {
        const f = Kirigami.Theme.smallFont
        f.bold = true
        f.capitalization = Font.AllUppercase
        f.letterSpacing = 0.8
        return f
    }

    implicitHeight: Kirigami.Units.gridUnit * 1.9
    readonly property color band: tones.color(root.look.tone)

    Tones { id: tones }

    Rectangle {
        anchors { fill: parent; topMargin: Kirigami.Units.smallSpacing }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.alpha(root.band, Style.BAND.start) }
            GradientStop { position: 0.6; color: Qt.alpha(root.band, Style.BAND.end) }
            GradientStop { position: 1; color: "transparent" }
        }
        Rectangle {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: 3
            color: root.band
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.largeSpacing
        anchors.rightMargin: Kirigami.Units.largeSpacing
        anchors.topMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing
        ActionIcon {
            glyph: root.look.glyph
            color: tones.color(root.look.tone)
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: implicitWidth
        }
        PlasmaComponents.Label {
            text: root.look.label
            font: root.headingFont
            color: root.band
        }
        Item { Layout.fillWidth: true }
    }
}
