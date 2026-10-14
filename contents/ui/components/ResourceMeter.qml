import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

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
        : label === "CPU" ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.highlightColor
    property bool bold: false
    property string numberColumnText: "1000.00%"
    readonly property font metricFont: {
        const result = Kirigami.Theme.smallFont
        result.bold = root.bold
        result.features = {"tnum": 1}
        return result
    }
    spacing: Kirigami.Units.smallSpacing / 2
    TextMetrics { id: cpuLabel; font: root.metricFont; text: root.compact ? "C" : "CPU" }
    TextMetrics { id: ramLabel; font: root.metricFont; text: root.compact ? "R" : "RAM" }
    TextMetrics { id: digits; font: number.font; text: root.numberColumnText }
    TextMetrics { id: actualDigits; font: number.font; text: number.text }
    PlasmaComponents.Label {
        text: root.compact ? root.label.slice(0, 1) : root.label
        Layout.preferredWidth: Math.ceil(Math.max(cpuLabel.advanceWidth, ramLabel.advanceWidth))
        Layout.minimumWidth: Layout.preferredWidth
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
        Layout.preferredWidth: Math.max(digits.advanceWidth, actualDigits.advanceWidth)
        Layout.minimumWidth: Math.max(digits.advanceWidth, actualDigits.advanceWidth)
        horizontalAlignment: Text.AlignRight
        font: root.metricFont
    }
    HoverHandler { id: hover }
    PlasmaComponents.ToolTip {
        visible: hover.hovered
        text: i18n("%1: %2% · bar scale: 0–%3%", root.label, root.value.toFixed(2), String(root.maximum))
    }
}
