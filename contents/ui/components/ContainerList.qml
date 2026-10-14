pragma ComponentBehavior: Bound

import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

/*
 * ContainerList — the "rows" view.
 *
 * A plain ListView of ContainerRow. The scroll view is transparent so the
 * delegate highlight and the surrounding popup share one background.
 */
PlasmaComponents.ScrollView {
        PlasmaComponents.ScrollBar.vertical.policy: PlasmaComponents.ScrollBar.AsNeeded
    id: root

    required property var backend
    required property var proxy
    required property var dialogs

    property int detailLevel: 1

    signal openDetail(string recordId)
    signal openOutput(string title, string content, bool live, string recordId)

    readonly property bool filtering: root.backend.total > 0 && view.count === 0

    background: null

    contentItem: ListView {
        id: view
        model: root.proxy
        currentIndex: -1
        keyNavigationEnabled: true
        activeFocusOnTab: true
        reuseItems: true
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        highlight: PlasmaExtras.Highlight {}
        highlightMoveDuration: Kirigami.Units.shortDuration
        highlightResizeDuration: 0
        contentWidth: width

        /* Headings only make sense while the default order keeps states together. */
        section.property: root.backend.cfg.sortRole === "sortKey" ? "stateGroup" : ""
        section.criteria: ViewSection.FullString
        section.delegate: ListSection {
            required property string section
            width: view.width
            group: section
        }

        delegate: ContainerRow {
            width: view.width
            backend: root.backend
            dialogs: root.dialogs
            detailLevel: root.detailLevel
            onOpenDetail: function (recordId) { root.openDetail(recordId) }
            onOpenOutput: function (title, content, live, recordId) {
                root.openOutput(title, content, live, recordId)
            }
        }

        Kirigami.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.largeSpacing * 2
            visible: view.count === 0
            text: {
                if (!root.backend.engineActive) return i18n("%1 is not running", root.backend.engineName)
                if (root.backend.refreshing) return i18n("Looking for containers…")
                if (root.backend.total === 0) {
                    return i18n("No containers yet.\nStart one with a tool such as Portainer, or from a terminal.")
                }
                return i18n("No container matches your search.")
            }
            icon.name: {
                if (!root.backend.engineActive) return "docker"
                if (root.backend.total === 0) return "view-list-tree"
                return "edit-find"
            }
        }
    }
}
