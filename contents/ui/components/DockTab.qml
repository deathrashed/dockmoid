import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/style.js" as Style

/* DockTab — a tab for the page dock: icon and label, a light wash and outline when current. */
Controls.AbstractButton {
    id: control
    property string glyph: "layers"
    property bool iconOnly: false

    checkable: false
    implicitHeight: Kirigami.Units.gridUnit * 1.7
    implicitWidth: control.iconOnly ? implicitHeight : row.implicitWidth + Kirigami.Units.largeSpacing * 2
    hoverEnabled: true
    Accessible.name: control.text

    // Centred as a group, so an icon-only tab draws its icon in the middle of
    // its square rather than against the left edge.
    contentItem: Item {
        implicitWidth: row.implicitWidth
        implicitHeight: row.implicitHeight
        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing
            ActionIcon {
                Layout.alignment: Qt.AlignVCenter
                glyph: control.glyph
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: implicitWidth
            }
            PlasmaComponents.Label {
                visible: !control.iconOnly
                text: control.text
                font.bold: control.checked
            }
        }
    }
    background: Rectangle {
        radius: Kirigami.Units.smallSpacing
        color: control.checked ? Qt.alpha(Kirigami.Theme.highlightColor, Style.ALPHA.tintFaint)
            : control.hovered ? Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface2) : "transparent"
        border.width: control.checked ? 1 : 0
        border.color: Qt.alpha(Kirigami.Theme.highlightColor, Style.WASH_BORDER.hover)
    }
    PlasmaComponents.ToolTip { visible: control.iconOnly && control.hovered; text: control.text }
}
