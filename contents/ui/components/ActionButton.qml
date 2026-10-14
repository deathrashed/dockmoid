import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/actionIcons.js" as ActionIcons

PlasmaComponents.Button {
    id: control
    property string glyph: "document-view"
    icon.name: ""
    icon.source: Qt.resolvedUrl(ActionIcons.path(glyph))
    contentItem: RowLayout {
        spacing: control.spacing
        ActionIcon {
            glyph: control.glyph
            color: control.enabled ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: implicitWidth
        }
        PlasmaComponents.Label {
            text: control.Kirigami.MnemonicData.richTextLabel
            font: control.font
            color: control.enabled ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
        }
    }
}
