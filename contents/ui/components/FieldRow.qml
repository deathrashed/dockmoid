import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kquickcontrolsaddons as KQuickControlsAddons
import org.kde.plasma.components as PlasmaComponents

/*
 * FieldRow — one "label: value" line on the detail page.
 *
 * Hides itself when the value is empty so the page does not show a column of
 * blank rows for fields a given container simply does not have (no ports, no
 * compose file, no healthcheck).
 */
Item {
    id: root

    property string label: ""
    property string value: ""
    property bool copyable: false
    /* Long values (mounts, commands) read better wrapped than elided. */
    property bool wrap: false

    readonly property bool hasValue: value !== "" && value !== "—"

    visible: hasValue
    implicitHeight: hasValue ? layout.implicitHeight + Kirigami.Units.smallSpacing : 0

    KQuickControlsAddons.Clipboard {
        id: clipboard
    }

    RowLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Kirigami.Units.largeSpacing
        anchors.rightMargin: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.Label {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 6
            Layout.alignment: Qt.AlignTop
            text: root.label
            color: Kirigami.Theme.disabledTextColor
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: root.value
            elide: root.wrap ? Text.ElideNone : Text.ElideMiddle
            wrapMode: root.wrap ? Text.WrapAnywhere : Text.NoWrap
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        }

        PlasmaComponents.ToolButton {
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.alignment: Qt.AlignTop
            visible: root.copyable
            display: PlasmaComponents.AbstractButton.IconOnly
            icon.name: "edit-copy"
            text: i18n("Copy")
            onClicked: clipboard.content = root.value
            PlasmaComponents.ToolTip { text: i18n("Copy %1", root.label) }
        }
    }
}
