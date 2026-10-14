pragma ComponentBehavior: Bound

import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

/*
 * ComposeGroupView — containers grouped by docker compose project.
 *
 * A homelab is almost always a set of projects, not a flat list of
 * containers, and "stop the whole stack" is the operation people actually
 * want. The group header carries the project name, its running/total counts
 * and the start / stop / restart trio.
 *
 * Sections come from a `groupKey` role, which is the compose project name for
 * project containers and the container name for standalone ones — so a plain
 * `docker run` container simply appears as a group of one rather than in a
 * meaningless "no project" bucket.
 *
 * This view keeps its own proxy, sorted by groupKey, because ListView
 * sections are only correct when the model is actually grouped. Sharing the
 * main proxy would mean switching to this view silently re-sorted the list and
 * table views too.
 */
Item {
    id: root

    required property var backend
    required property var dialogs
    required property string searchText
    /* The same row filter the other views use, so search and "problems only"
       behave identically here. */
    required property var rowFilter

    property int detailLevel: 1

    signal openDetail(string recordId)
    signal openOutput(string title, string content, bool live, string recordId)

    readonly property var cfg: plasmoid.configuration

    /* Project-wide compose actions, run from the group header's menu. */
    function runCompose(groupKey, verb) {
        var rec = root.backend.findGroupRecord(groupKey)
        if (rec) projectActions.runCompose(rec,verb,verb === "down")
    }
    ContainerActions { id: projectActions; backend: root.backend; dialogs: root.dialogs; record: null
        onOpenOutput: function(title,content,live,recordId) { root.openOutput(title,content,live,recordId) }
    }

    KItemModels.KSortFilterProxyModel {
        id: groupProxy
        sourceModel: root.backend.containerModel
        filterRowCallback: root.rowFilter
        filterCaseSensitivity: Qt.CaseInsensitive
        sortCaseSensitivity: Qt.CaseInsensitive
        recursiveFilteringEnabled: true
        dynamicSortFilter: true
        sortRoleName: "groupKey"
        sortOrder: Qt.AscendingOrder
    }

    PlasmaComponents.ScrollView {
        PlasmaComponents.ScrollBar.vertical.policy: PlasmaComponents.ScrollBar.AsNeeded
        id: scroll
        anchors.fill: parent
        background: null

        contentItem: ListView {
            id: view
            model: groupProxy
            width: scroll.width
            currentIndex: -1
            reuseItems: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            section.property: "groupKey"
            section.criteria: ViewSection.FullString
            section.delegate: GroupHeader {
                width: view.width
                backend: root.backend
                // A section delegate is handed its section value as an injected
                // role, so it has to be declared. Without the declaration the
                // bare `section` below is an undefined identifier.
                required property string section
                groupKey: section
                filtering: root.searchText.length > 0
                onComposeRequested: function (verb) { root.runCompose(section, verb) }
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
                text: !root.backend.engineActive
                    ? i18n("%1 is not running", root.backend.engineName)
                    : (root.backend.total === 0
                       ? i18n("No containers yet.")
                       : i18n("No container matches."))
            }
        }
    }
}
