import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/style.js" as Style

/* ListSection — the quiet heading above a run of containers that share a state. */
Item {
    id: root
    /* "pinned", "attention", "running", "stopped" or "not-created". */
    property string group: ""

    readonly property var looks: ({
        "pinned": {label: i18n("Pinned"), glyph: "pin"},
        "attention": {label: i18n("Needs attention"), glyph: "triangle-alert"},
        "running": {label: i18n("Running"), glyph: "circle-play"},
        "stopped": {label: i18n("Stopped"), glyph: "circle-pause"},
        "not-created": {label: i18n("Not created"), glyph: "package-plus"}
    })
    readonly property var look: root.looks[root.group] || ({label: root.group, glyph: "layers"})
    readonly property font headingFont: {
        const f = Kirigami.Theme.smallFont
        f.bold = true
        f.capitalization = Font.AllUppercase
        f.letterSpacing = 0.8
        return f
    }

    implicitHeight: Kirigami.Units.gridUnit * 1.8

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.largeSpacing
        anchors.rightMargin: Kirigami.Units.largeSpacing
        anchors.topMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing
        ActionIcon {
            glyph: root.look.glyph
            opacity: Style.TEXT.soft
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: implicitWidth
        }
        PlasmaComponents.Label {
            text: root.look.label
            font: root.headingFont
            opacity: Style.TEXT.soft
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.borderFaint)
        }
    }
}
