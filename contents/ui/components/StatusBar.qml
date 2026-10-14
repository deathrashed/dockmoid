import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/style.js" as Style

/*
 * StatusBar — the footer: how many containers are in each state (tap one to
 * filter), and the host's CPU and RAM. Coloured icons, plain numbers.
 */
Item {
    id: root
    required property var backend
    signal countFilter(string state)
    signal attentionFilterRequested()
    readonly property var cfg: plasmoid.configuration
    readonly property bool compact: width < 560

    implicitHeight: Math.max(row.implicitHeight, Kirigami.Units.gridUnit * 1.5) + Kirigami.Units.smallSpacing * 2

    Tones { id: tones }

    Rectangle { anchors.fill: parent; color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface1) }

    component Count: Item {
        id: count
        property int value: 0
        property string glyph: "layers"
        property string description: ""
        property string toneName: "muted"
        property string filterState: "all"
        property bool attention: false
        implicitWidth: line.implicitWidth
        implicitHeight: line.implicitHeight
        RowLayout {
            id: line
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing / 2
            ActionIcon { glyph: count.glyph; color: tones.color(count.toneName); implicitWidth: root.compact ? 12 : Kirigami.Units.iconSizes.small; implicitHeight: implicitWidth }
            PlasmaComponents.Label { text: String(count.value); font.pointSize: root.compact ? Kirigami.Theme.smallFont.pointSize : Kirigami.Theme.defaultFont.pointSize + 1; font.bold: true; font.features: ({"tnum": 1}) }
        }
        HoverHandler { id: countHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: count.attention ? root.attentionFilterRequested() : root.countFilter(count.filterState) }
        PlasmaComponents.ToolTip { visible: countHover.hovered; text: count.description }
        Accessible.name: description
        Accessible.role: Accessible.Button
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            id: counts
            objectName: "footerCounts"
            spacing: root.compact ? 3 : Kirigami.Units.smallSpacing * 2
            Count { value: root.backend.running; glyph: "circle-play"; toneName: "ok"; description: i18n("%1 running containers · click to filter", String(value)); filterState: "running" }
            Count { value: root.backend.stopped; glyph: "circle-pause"; toneName: "slate"; description: i18n("%1 stopped containers · click to filter", String(value)); filterState: "stopped" }
            Count { value: root.backend.notCreated; glyph: "package-plus"; toneName: "sky"; description: i18n("%1 configured services not created · click to filter", String(value)); filterState: "not-created" }
            Count { value: root.backend.total; glyph: "layers"; toneName: "indigo"; description: i18n("%1 containers and configured services · show all", String(value)); filterState: "all" }
            Count { value: root.backend.problemCount; glyph: "triangle-alert"; toneName: root.backend.problemCount > 0 ? "rose" : "slate"; description: i18n("%1 containers need attention · click to filter", String(value)); attention: true }
        }

        Item { Layout.fillWidth: true; Layout.minimumWidth: 0 }

        RowLayout {
            id: meters
            objectName: "footerResourceMeters"
            visible: root.backend.running > 0
            spacing: root.compact ? 4 : Kirigami.Units.smallSpacing * 2
            ResourceMeter { label: "CPU"; value: root.backend.cpuSum; maximum: 20; bold: true; compact: root.compact; barWidth: root.compact ? 12 : 36; numberColumnText: root.compact ? "00.00%" : "1000.00%" }
            ResourceMeter { label: "RAM"; value: root.backend.memSum; maximum: 20; bold: true; compact: root.compact; barWidth: root.compact ? 12 : 36; numberColumnText: root.compact ? "00.00%" : "1000.00%" }
        }
    }
}
