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
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: count.attention ? root.attentionFilterRequested() : root.countFilter(count.filterState) }
        Tip { text: count.description }
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
            Count { value: root.backend.stopped; glyph: "circle-stop"; toneName: "rose"; description: i18n("%1 stopped containers · click to filter", String(value)); filterState: "stopped" }
            Count { value: root.backend.notCreated; glyph: "circle-plus"; toneName: "blue"; description: i18n("%1 Compose services pending deployment · click to filter", String(value)); filterState: "not-created" }
            Count { value: root.backend.problemCount; glyph: "circle-alert"; toneName: "yellow"; description: i18n("%1 containers need attention · click to filter", String(value)); attention: true }
            Count { value: root.backend.total; glyph: "circle-ellipsis"; toneName: "slate"; description: i18n("%1 containers and configured services · show all", String(value)); filterState: "all" }
        }

        Item { Layout.fillWidth: true; Layout.minimumWidth: 0 }

        RowLayout {
            id: meters
            objectName: "footerResourceMeters"
            visible: root.backend.running > 0 && !root.compact
            spacing: Kirigami.Units.smallSpacing * 2
            ResourceMeter { label: "CPU"; value: root.backend.cpuSum; maximum: 20; bold: true; barWidth: 36; numberColumnText: "1000.00%" }
            ResourceMeter { label: "RAM"; value: root.backend.memSum; maximum: 20; bold: true; barWidth: 36; numberColumnText: "1000.00%" }
        }
        // A narrow popup has no room for bars, so the totals are plain words.
        RowLayout {
            visible: root.backend.running > 0 && root.compact
            spacing: Kirigami.Units.smallSpacing
            PlasmaComponents.Label {
                text: i18n("CPU %1%", root.backend.cpuSum.toFixed(1))
                font: Kirigami.Theme.smallFont
                color: Style.HUE.cyan
            }
            PlasmaComponents.Label { text: "·"; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor }
            PlasmaComponents.Label {
                text: i18n("RAM %1%", root.backend.memSum.toFixed(1))
                font: Kirigami.Theme.smallFont
                color: Style.HUE.fuchsia
            }
            Tip { text: i18n("CPU and memory used by all running containers") }
        }
    }
}
