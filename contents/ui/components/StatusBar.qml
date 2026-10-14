import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/style.js" as Style

Item {
    id: root
    required property var backend
    signal countFilter(string state)
    signal attentionFilterRequested()
    /* The overview strip already shows the counts on the main page. */
    property bool showCounts: true
    readonly property var cfg: plasmoid.configuration
    implicitHeight: Math.max(counts.implicitHeight, meters.implicitHeight) + Kirigami.Units.smallSpacing * 2
    Rectangle { anchors.fill: parent; color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface1) }

    readonly property bool compact: width < 560
    component Count: Item {
        id: count
        property int value: 0
        property string glyph: "package"
        property string description: ""
        property string filterState: "all"
        property bool attention: false
        property color tint: Kirigami.Theme.textColor
        implicitWidth: row.implicitWidth
        implicitHeight: row.implicitHeight
        RowLayout {
            id: row
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing / 2
            ActionIcon { glyph: count.glyph; color: count.tint; implicitWidth: root.compact ? 12 : Kirigami.Units.iconSizes.small; implicitHeight: implicitWidth }
            PlasmaComponents.Label { text: String(count.value); font.pointSize: root.compact ? Kirigami.Theme.smallFont.pointSize : Kirigami.Theme.defaultFont.pointSize + 1; font.bold: true; font.features: ({"tnum":1}); color: Kirigami.Theme.textColor }
        }
        HoverHandler { id: countHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: count.attention ? root.attentionFilterRequested() : root.countFilter(count.filterState) }
        PlasmaComponents.ToolTip { visible: countHover.hovered; text: count.description }
        Accessible.name: description
        Accessible.role: Accessible.Button
    }

    RowLayout {
        id: footerRow
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing
        RowLayout {
        id: counts
        objectName: "footerCounts"
        visible: root.showCounts
        spacing: root.compact ? 3 : Kirigami.Units.smallSpacing * 1.5
        Count { value: root.backend.running; glyph: "media-playback-start"; tint: Kirigami.Theme.positiveTextColor; description: i18n("%1 running containers · click to filter", String(value)); filterState: "running" }
        Count { value: root.backend.stopped; glyph: "media-playback-stop"; description: i18n("%1 stopped containers · click to filter", String(value)); filterState: "stopped" }
        Count { value: root.backend.notCreated; glyph: "list-add"; tint: Kirigami.Theme.linkColor; description: i18n("%1 configured services not created · click to filter", String(value)); filterState: "not-created" }
        Count { value: root.backend.total; glyph: "package"; description: i18n("%1 containers and configured services · show all", String(value)); filterState: "all" }
        Count { value: root.backend.problemCount; glyph: "dialog-warning"; tint: root.backend.problemCount > 0 ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor; description: i18n("%1 containers need attention · click to filter", String(value)); attention: true }
        }
        Item {Layout.fillWidth:true;Layout.minimumWidth:0}
        RowLayout {
            id: meters
            objectName: "footerResourceMeters"
            visible: root.backend.running > 0
            spacing: root.compact ? 4 : Kirigami.Units.smallSpacing * 2
            ResourceMeter {label:"CPU";value:root.backend.cpuSum;maximum:20;bold:true;compact:root.compact;barWidth:root.compact?12:36;numberColumnText:root.compact?"00.00%":"1000.00%"}
            ResourceMeter {label:"RAM";value:root.backend.memSum;maximum:20;bold:true;compact:root.compact;barWidth:root.compact?12:36;numberColumnText:root.compact?"00.00%":"1000.00%"}
        }
    }
}
