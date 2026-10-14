import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

/* Plasma's MenuItem ignores icon.color. Draw a theme-coloured SVG in every delegate. */
PlasmaComponents.MenuItem {
    id: control
    // Menu's ListView retains invisible delegates unless their height collapses.
    height: visible ? implicitHeight : 0
    property string nativeIconName: ""
    function updateMenuWidth() {
        var list = control.menu ? control.menu.contentItem as ListView : null
        if (list && list.contentItem) list.contentItem.childrenChanged()
    }
    onImplicitWidthChanged: updateMenuWidth()
    onMenuChanged: updateMenuWidth()
    arrow: ActionIcon {
        glyph: control.mirrored ? "go-previous-arrow" : "go-next"
        x: control.mirrored ? control.padding : control.width - width - control.padding
        y: (control.height - height) / 2
        width: Kirigami.Units.iconSizes.small
        height: width
        visible: control.subMenu !== null
        color: control.enabled ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
    }
    contentItem: RowLayout {
        spacing: Kirigami.Units.smallSpacing
        Item { Layout.preferredWidth: control.checkable ? control.indicator.width : Kirigami.Units.smallSpacing }
        ActionIcon {
            assetName: String(control.icon.source).split("/").pop().replace(/\.svg$/, "")
            visible: !nativeIcon.visible && String(control.icon.source) !== ""
            color: control.enabled ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
        }
        Kirigami.Icon {
            id: nativeIcon
            source: control.nativeIconName
            fallback: ""
            visible: control.nativeIconName !== "" && valid
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: control.Kirigami.MnemonicData.richTextLabel
            font: control.font
            color: control.enabled ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
            elide: Text.ElideRight
        }
    }
}
