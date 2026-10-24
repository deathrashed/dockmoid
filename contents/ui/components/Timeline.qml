import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/status.js" as Status
import "../../lib/style.js" as Style

/*
 * Timeline — when a container started, stopped or was created, as clock
 * icons and ages: [clock-arrow-up] 7h 24m, [clock-arrow-down] Oct 10 · 9d,
 * [clock-plus] 23h. The icon says which; the tooltip says it in words with the
 * exact date and time. Without inspect times (Podman, a customised policy
 * command) it falls back to the engine's own status text.
 */
Item {
    id: root

    property var record: null
    /* Re-read ages without a new record; the row's revision changes do the rest. */
    property double now: Date.now()

    readonly property var entries: Status.timeline(root.record, root.now)
    readonly property string fallback: root.record && root.record.state !== "not-created" ? String(root.record.status || "") : ""

    implicitWidth: line.implicitWidth
    implicitHeight: Math.max(line.implicitHeight, Kirigami.Units.iconSizes.small)

    Timer { interval: 60000; repeat: true; running: root.visible && root.entries.length > 0; onTriggered: root.now = Date.now() }

    function when(at) {
        const date = new Date(at)
        const age = root.now - at
        if (age < 86400000) return Qt.formatTime(date, Locale.ShortFormat)
        return Qt.formatDate(date, age < 300 * 86400000 ? "MMM d" : "MMM d yyyy")
    }
    function exact(at) { return Qt.formatDateTime(new Date(at), Locale.LongFormat) }
    function words(entry) {
        switch (entry.kind) {
        case "up": return i18n("Started %1\nRunning for %2", root.exact(entry.at), entry.span)
        case "down": return i18n("Stopped %1\n%2 ago", root.exact(entry.at), entry.span)
        default: return i18n("Created %1\n%2 ago", root.exact(entry.at), entry.span)
        }
    }

    RowLayout {
        id: line
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        Repeater {
            model: root.entries
            delegate: RowLayout {
                id: entryItem
                required property var modelData
                spacing: Kirigami.Units.smallSpacing / 2
                Layout.minimumWidth: 0
                ActionIcon {
                    glyph: entryItem.modelData.kind === "up" ? "clock-arrow-up" : entryItem.modelData.kind === "down" ? "clock-arrow-down" : "clock-plus"
                    // Opaque colour (the SVG renderer ignores alpha); softness comes from opacity.
                    color: Kirigami.Theme.textColor
                    opacity: Style.TEXT.soft
                    implicitWidth: Kirigami.Units.iconSizes.small * 0.85
                    implicitHeight: implicitWidth
                }
                PlasmaComponents.Label {
                    text: entryItem.modelData.kind === "down" ? i18nc("stop date · time since", "%1 · %2", root.when(entryItem.modelData.at), entryItem.modelData.span) : entryItem.modelData.span
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                    elide: Text.ElideRight
                }
                Tip { text: root.words(entryItem.modelData) }
            }
        }
        PlasmaComponents.Label {
            visible: root.entries.length === 0 && root.fallback !== ""
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: root.fallback
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            elide: Text.ElideRight
        }
        Item { Layout.fillWidth: true; visible: root.entries.length > 0 }
    }
}
