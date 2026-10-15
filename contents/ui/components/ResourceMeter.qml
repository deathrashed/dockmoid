import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/style.js" as Style

RowLayout {
    id: root
    property string label: "CPU"
    property real value: 0
    property real maximum: 5
    /* Colour the bar amber from warnAt and red from twice that; 0 keeps it plain. */
    property real warnAt: 0
    property bool compact: false
    property real barWidth: compact ? 28 : 44
    property color barColor: root.warnAt > 0 && root.value >= root.warnAt * 2 ? Kirigami.Theme.negativeTextColor
        : root.warnAt > 0 && root.value >= root.warnAt ? Kirigami.Theme.neutralTextColor
        : label === "CPU" ? Style.HUE.cyan : Style.HUE.fuchsia
    property bool bold: false
    property string numberColumnText: "1000.00%"
    readonly property font metricFont: {
        const result = Kirigami.Theme.smallFont
        result.bold = root.bold
        result.features = {"tnum": 1}
        return result
    }
    spacing: Kirigami.Units.smallSpacing / 2
    FontMetrics { id: fm; font: root.metricFont }
    readonly property real labelWidth: Math.ceil(Math.max(fm.advanceWidth(root.compact ? "C" : "CPU"), fm.advanceWidth(root.compact ? "R" : "RAM")))
    PlasmaComponents.Label {
        text: root.compact ? root.label.slice(0, 1) : root.label
        Layout.preferredWidth: root.labelWidth
        Layout.minimumWidth: root.labelWidth
        font: root.metricFont
        color: Kirigami.Theme.disabledTextColor
    }
    MiniBar {
        label: root.label
        value: root.value
        maximum: root.maximum
        barColor: root.barColor
        Layout.preferredWidth: root.barWidth
        Layout.minimumWidth: root.barWidth
        Layout.maximumWidth: root.barWidth
    }
    PlasmaComponents.Label {
        id: number
        text: root.value.toFixed(2) + "%"
        Layout.preferredWidth: Math.max(fm.advanceWidth(root.numberColumnText), fm.advanceWidth(number.text))
        Layout.minimumWidth: Layout.preferredWidth
        horizontalAlignment: Text.AlignRight
        font: root.metricFont
    }
}
