import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/style.js" as Style

/* Pill — a small rounded badge for a state or a fact ("Running", "Official"). */
Rectangle {
    id: root

    property string text: ""
    /* "ok", "info", "warn", "bad" or "muted"; see Tones. */
    property string tone: "muted"
    property string glyph: ""
    readonly property color toneColor: tones.color(root.tone)

    implicitHeight: label.implicitHeight + Kirigami.Units.smallSpacing * 1.5
    implicitWidth: line.implicitWidth + Kirigami.Units.smallSpacing * 3
    radius: height / 2
    color: Qt.alpha(root.toneColor, Style.ALPHA.tintStrong)
    border.width: 1
    border.color: Qt.alpha(root.toneColor, Style.ALPHA.borderAccent)

    Tones { id: tones }

    RowLayout {
        id: line
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing / 2
        ActionIcon {
            visible: root.glyph !== ""
            glyph: root.glyph
            color: root.toneColor
            implicitWidth: Kirigami.Units.iconSizes.small * 0.75
            implicitHeight: implicitWidth
        }
        PlasmaComponents.Label {
            id: label
            text: root.text
            font: Kirigami.Theme.smallFont
            color: root.toneColor
        }
    }
}
