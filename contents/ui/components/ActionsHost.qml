import QtQuick

/*
 * ActionsHost — a container's action menu, built the first time it is opened.
 *
 * Every row used to own two complete menus (and a clipboard helper) from the
 * moment it appeared, though almost no row's menu is ever opened. This keeps the
 * same properties, signals and popup() as ContainerActions and builds the real
 * menu on demand.
 */
Item {
    id: host
    required property var backend
    required property var record
    required property var dialogs
    property bool browserOnly: false
    property var excludedActions: []
    signal openDetail(string recordId)
    signal openOutput(string title, string content, bool live, string recordId)

    width: 0
    height: 0

    function popup(anchor, x, y) {
        loader.active = true
        if (loader.item) (loader.item as ContainerActions).popup(anchor, x, y)
    }
    function showInspect(rec) {
        loader.active = true
        if (loader.item) (loader.item as ContainerActions).showInspect(rec)
    }

    Loader {
        id: loader
        active: false
        sourceComponent: ContainerActions {
            backend: host.backend
            record: host.record
            dialogs: host.dialogs
            browserOnly: host.browserOnly
            excludedActions: host.excludedActions
            onOpenDetail: function(recordId) { host.openDetail(recordId) }
            onOpenOutput: function(title, content, live, recordId) { host.openOutput(title, content, live, recordId) }
        }
    }
}
