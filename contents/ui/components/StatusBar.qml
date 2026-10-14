import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/style.js" as Style

/*
 * StatusBar — the footer: which engine, how many containers are in each state
 * (tap one to filter), when the data was last read, and the host's CPU and RAM.
 */
Item {
    id: root
    required property var backend
    signal countFilter(string state)
    signal attentionFilterRequested()
    readonly property var cfg: plasmoid.configuration
    readonly property bool wide: width >= Kirigami.Units.gridUnit * 38
    readonly property bool compact: width < 560
    /* The "updated" text only fits on a roomy bar. */
    readonly property bool roomy: width >= Kirigami.Units.gridUnit * 52
    property double now: Date.now()

    implicitHeight: Math.max(row.implicitHeight, Kirigami.Units.gridUnit * 1.7) + Kirigami.Units.smallSpacing * 2

    Tones { id: tones }

    Timer {
        interval: 5000
        repeat: true
        running: root.visible && root.roomy
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }
    function updatedText() {
        const ms = root.backend.lastUpdatedMs
        if (ms <= 0) return i18n("Not refreshed yet")
        const seconds = Math.max(0, Math.round((root.now - ms) / 1000))
        if (seconds < 10) return i18n("Updated just now")
        if (seconds < 90) return i18n("Updated %1 s ago", seconds)
        return i18n("Updated %1 min ago", Math.round(seconds / 60))
    }

    Rectangle { anchors.fill: parent; color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface2) }
    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 1
        color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.borderFaint)
    }

    component Count: Item {
        id: count
        property int value: 0
        property string glyph: "layers"
        property string label: ""
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
            ActionIcon { glyph: count.glyph; color: tones.color(count.toneName); implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: implicitWidth }
            PlasmaComponents.Label { text: String(count.value); font.bold: true; font.features: ({"tnum": 1}) }
            PlasmaComponents.Label { visible: root.wide; text: count.label; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor }
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
        anchors.leftMargin: Kirigami.Units.largeSpacing
        anchors.rightMargin: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        Pill {
            visible: !root.compact
            dense: true
            variant: "outline"
            tone: root.backend.engineKnown && !root.backend.engineActive ? "bad" : "ok"
            statusDot: true
            text: root.backend.engineName + (root.backend.engineInfo && root.backend.engineInfo.serverVersion ? " " + root.backend.engineInfo.serverVersion : "")
        }

        RowLayout {
            id: counts
            objectName: "footerCounts"
            spacing: root.compact ? Kirigami.Units.smallSpacing * 1.5 : Kirigami.Units.largeSpacing
            Count { value: root.backend.running; glyph: "circle-play"; toneName: "ok"; label: i18n("running"); description: i18n("%1 running containers · click to filter", String(value)); filterState: "running" }
            Count { value: root.backend.stopped; glyph: "circle-pause"; toneName: "slate"; label: i18n("stopped"); description: i18n("%1 stopped containers · click to filter", String(value)); filterState: "stopped" }
            Count { value: root.backend.notCreated; glyph: "package-plus"; toneName: "cyan"; label: i18n("not created"); description: i18n("%1 configured services not created · click to filter", String(value)); filterState: "not-created" }
            Count { value: root.backend.total; glyph: "layers"; toneName: "blue"; label: i18n("total"); description: i18n("%1 containers and configured services · show all", String(value)); filterState: "all" }
            Count { value: root.backend.problemCount; glyph: "triangle-alert"; toneName: root.backend.problemCount > 0 ? "bad" : "slate"; label: i18n("attention"); description: i18n("%1 containers need attention · click to filter", String(value)); attention: true }
        }

        Item { Layout.fillWidth: true; Layout.minimumWidth: 0 }

        PlasmaComponents.Label {
            visible: root.roomy
            text: root.updatedText()
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }
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
