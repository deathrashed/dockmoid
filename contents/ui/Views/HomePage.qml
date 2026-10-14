pragma ComponentBehavior: Bound

import QtQuick

import "../components" as Components

/*
 * HomePage — the container list, rendered three ways.
 *
 * Only one of the three is ever instantiated (a Loader, not three Items with
 * visible toggles), so switching views does not leave three copies of the list
 * alive re-evaluating bindings behind the visible one.
 */
Item {
    id: root

    required property var backend
    required property var proxy
    required property var dialogs

    required property int viewMode
    required property int detailLevel
    required property string searchText
    required property var rowFilter

    signal openDetail(string recordId)
    signal openOutput(string title, string content, bool live, string recordId)

    Component {
        id: listComponent
        Components.ContainerList {
            backend: root.backend
            proxy: root.proxy
            dialogs: root.dialogs
            detailLevel: root.detailLevel
            onOpenDetail: function (recordId) { root.openDetail(recordId) }
            onOpenOutput: function (title, content, live, recordId) {
                root.openOutput(title, content, live, recordId)
            }
        }
    }

    Component {
        id: tableComponent
        Components.ContainerTable {
            backend: root.backend
            proxy: root.proxy
            dialogs: root.dialogs
            onOpenDetail: function (recordId) { root.openDetail(recordId) }
            onOpenOutput: function (title, content, live, recordId) {
                root.openOutput(title, content, live, recordId)
            }
        }
    }

    Component {
        id: groupComponent
        Components.ComposeGroupView {
            backend: root.backend
            dialogs: root.dialogs
            searchText: root.searchText
            rowFilter: root.rowFilter
            detailLevel: root.detailLevel
            onOpenDetail: function (recordId) { root.openDetail(recordId) }
            onOpenOutput: function (title, content, live, recordId) {
                root.openOutput(title, content, live, recordId)
            }
        }
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.viewMode === 1
            ? tableComponent
            : (root.viewMode === 2 ? groupComponent : listComponent)
    }
}
