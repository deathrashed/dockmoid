import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

/*
 * LogDigest — what keeps going wrong in a container's recent log, in plain
 * sentences: one line per problem with how often it happened, most serious
 * first, instead of the raw lines. `digest` is the result of
 * Status.digestLogs (lib/status.js); `checkedAt` says when it was read.
 */
ColumnLayout {
    id: root
    property var digest: null
    property double checkedAt: 0
    spacing: Kirigami.Units.smallSpacing

    function sentence(item) {
        if (item.kind === "loop") return i18np("Repeated %1 time in a row: it keeps happening, likely a loop or retry storm",
                                               "Repeated %1 times in a row: it keeps happening, likely a loop or retry storm", item.run)
        if (item.kind === "recurring") return i18np("Seen %1 time in these lines", "Seen %1 times in these lines", item.count)
        return i18n("Seen once")
    }

    PlasmaComponents.Label {
        Layout.fillWidth: true
        visible: root.digest === null
        color: Kirigami.Theme.disabledTextColor
        text: i18n("Reading the newest log lines…")
    }
    PlasmaComponents.Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        visible: root.digest !== null
        text: {
            if (!root.digest) return ""
            if (root.digest.lines === 0) return i18n("No log lines to read.")
            if (root.digest.errors === 0 && root.digest.warnings === 0) return i18n("Nothing that looks like an error or warning in the last %1 lines.", root.digest.lines)
            return i18n("In the last %1 lines: %2 errors and %3 warnings.", root.digest.lines, root.digest.errors, root.digest.warnings)
        }
    }
    Repeater {
        model: root.digest ? root.digest.items : []
        delegate: RowLayout {
            id: row
            required property var modelData
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Layout.alignment: Qt.AlignTop
            ActionIcon {
                glyph: row.modelData.kind === "loop" ? "rotate-cw" : row.modelData.kind === "recurring" ? "repeat" : "circle-alert"
                color: row.modelData.level === "error" ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.neutralTextColor
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: implicitWidth
                Layout.alignment: Qt.AlignTop
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 0
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WrapAnywhere
                    text: row.modelData.sample
                    font.family: Kirigami.Theme.fixedWidthFont.family
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    textFormat: Text.PlainText
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: root.sentence(row.modelData)
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                }
            }
        }
    }
}
