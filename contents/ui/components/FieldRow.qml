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
    property string copyValue: ""
    property bool copyable: false
    property bool revealable: false
    property bool revealed: false
    /* Long values (mounts, commands) read better wrapped than elided. */
    property bool wrap: false
    /* A lucide icon and tone beside the label. */
    property string glyph: ""
    property string glyphTone: "muted"

    readonly property bool hasValue: value !== "" && value !== "—" && value.toLowerCase() !== "unavailable"
    readonly property string fullValue: copyValue !== "" ? copyValue : value

    visible: hasValue
    /* Text sits on the centre line of the copy/reveal buttons, so a label, its
       value and its buttons line up instead of the value drifting lower. */
    readonly property real textInset: root.copyable || root.revealable
        ? Math.max(0, (copyButton.implicitHeight - lineMetrics.height) / 2) : 0
    FontMetrics { id: lineMetrics; font: Kirigami.Theme.defaultFont }
    implicitHeight: hasValue ? layout.implicitHeight + Kirigami.Units.smallSpacing : 0
    implicitWidth: layout.implicitWidth

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

        RowLayout {
            Layout.fillWidth: false
            Layout.preferredWidth: Kirigami.Units.gridUnit * 7
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: root.textInset
            spacing: Kirigami.Units.smallSpacing
            ActionIcon {
                visible: root.glyph !== ""
                glyph: root.glyph
                color: rowTones.color(root.glyphTone)
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: implicitWidth
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: root.label
                color: Kirigami.Theme.disabledTextColor
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                elide: Text.ElideRight
            }
        }
        Tones { id: rowTones }

        PlasmaComponents.Label {
            id: valueLabel
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: root.textInset
            Layout.minimumWidth: 0
            text: root.revealed ? root.fullValue : root.value
            elide: root.wrap ? Text.ElideNone : Text.ElideMiddle
            wrapMode: root.wrap ? Text.Wrap : Text.NoWrap
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
            PlasmaComponents.ToolTip { text: root.fullValue }
        }

        ActionToolButton {
            Layout.alignment: Qt.AlignTop
            implicitHeight: Kirigami.Units.gridUnit * 1.35
            visible: root.revealable
            glyph: "view-visible"
            text: root.revealed ? i18n("Hide full value") : i18n("Reveal full value")
            onClicked: root.revealed = !root.revealed
        }

        ActionToolButton {
            id: copyButton
            // Compact, so rows with a copy button are barely taller than rows without.
            implicitHeight: Kirigami.Units.gridUnit * 1.35
            Layout.preferredWidth: implicitWidth
            Layout.alignment: Qt.AlignTop
            visible: root.copyable
            glyph: "edit-copy"
            text: i18n("Copy")
            onClicked: clipboard.content = root.fullValue
            PlasmaComponents.ToolTip { text: i18n("Copy %1", root.label) }
        }
    }
}
