import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.kquickcontrolsaddons as KQuickControlsAddons
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

/*
 * LogViewer — text with the things you want when reading logs: filter, errors
 * only, keep-scrolled-to-the-end, wrap and copy. Used for container logs and
 * for any other command output (inspect, pulls, compose).
 */
Item {
    id: root

    property string text: ""
    /* Offer the errors-only toggle and stick to the bottom as lines arrive. */
    property bool logMode: false
    property string emptyText: i18n("No output yet.")

    property string needle: ""
    property bool errorsOnly: false
    property bool follow: true
    property bool wrap: true

    readonly property var allLines: String(root.text).split("\n")

    readonly property var shownLines: {
        var lines = root.allLines
        var n = root.needle.toLowerCase()
        if (n === "" && !root.errorsOnly) return lines
        var level = /\b(error|err|fatal|panic|crit|critical|warn|warning|exception|fail|failed|denied|refused)\b/i
        return lines.filter(function (l) {
            return (n === "" || l.toLowerCase().indexOf(n) !== -1)
                && (!root.errorsOnly || level.test(l))
        })
    }

    readonly property string shown: root.shownLines.join("\n")

    /* The ScrollView's own Flickable, held as a plain var so it is duck-typed. */
    readonly property var flickable: scroll.contentItem

    function scrollToEnd() {
        var flick = root.flickable
        if (flick && flick.contentHeight !== undefined)
            flick.contentY = Math.max(0, flick.contentHeight - flick.height)
    }

    onShownChanged: if (root.logMode && root.follow) Qt.callLater(root.scrollToEnd)

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaExtras.SearchField {
                id: filterField
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 16
                placeholderText: i18n("Filter lines")
                onTextChanged: root.needle = text
                Keys.onEscapePressed: clear()
            }

            PlasmaComponents.Label {
                visible: root.needle !== "" || root.errorsOnly
                text: i18n("%1 of %2", root.shownLines.length, root.allLines.length)
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }

            Item { Layout.fillWidth: true }

            PlasmaComponents.ToolButton {
                id: errorsButton
                visible: root.logMode
                display: PlasmaComponents.AbstractButton.IconOnly
                icon.name: "dialog-warning"
                text: i18n("Only errors and warnings")
                checkable: true
                checked: root.errorsOnly
                onClicked: root.errorsOnly = checked
                PlasmaComponents.ToolTip { text: errorsButton.text }
            }

            PlasmaComponents.ToolButton {
                id: followButton
                visible: root.logMode
                display: PlasmaComponents.AbstractButton.IconOnly
                icon.name: "go-bottom"
                text: i18n("Keep scrolled to the newest line")
                checkable: true
                checked: root.follow
                onClicked: { root.follow = checked; if (checked) root.scrollToEnd() }
                PlasmaComponents.ToolTip { text: followButton.text }
            }

            PlasmaComponents.ToolButton {
                id: wrapButton
                display: PlasmaComponents.AbstractButton.IconOnly
                icon.name: "text-wrap"
                text: i18n("Wrap lines")
                checkable: true
                checked: root.wrap
                onClicked: root.wrap = checked
                PlasmaComponents.ToolTip { text: wrapButton.text }
            }

            PlasmaComponents.ToolButton {
                id: copyButton
                display: PlasmaComponents.AbstractButton.IconOnly
                icon.name: "edit-copy"
                text: i18n("Copy what is shown")
                onClicked: clipboard.content = root.shown
                PlasmaComponents.ToolTip { text: copyButton.text }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.alpha(Kirigami.Theme.textColor, 0.2)
        }

        QQC2.ScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            background: null

            // A direct child, not a contentItem: ScrollView supplies its own Flickable.
            QQC2.TextArea {
                readOnly: true
                selectByMouse: true
                wrapMode: root.wrap ? TextEdit.WrapAnywhere : TextEdit.NoWrap
                font.family: "monospace"
                font.pointSize: 9
                text: root.shown !== "" ? root.shown : root.emptyText
                background: null
            }
        }
    }

    KQuickControlsAddons.Clipboard {
        id: clipboard
    }
}
