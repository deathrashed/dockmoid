pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

/*
 * ResourcesPage — images, volumes and networks: what is taking up space, what
 * is in use, and what can go.
 *
 * Containers are the interesting part of Docker, but disk fills up with the
 * things around them. "Unused" is shown wherever Docker tells us enough to say
 * so (an image no container uses, a volume nothing mounts), and removal always
 * asks first.
 */
Item {
    id: root

    required property var backend
    required property var dialogs
    required property var navigator

    property int tab: 0                       // 0 images, 1 volumes, 2 networks
    property bool unusedOnly: false
    readonly property var kinds: ["images", "volumes", "networks"]
    readonly property string kind: root.kinds[root.tab]

    readonly property var items: {
        var list = root.backend.resources[root.kind] || []
        if (!root.unusedOnly) return list
        return list.filter(function (it) { return root.isUnused(it) })
    }

    function isUnused(it) {
        if (root.kind === "images") return it.containers === 0
        if (root.kind === "volumes") return it.links === 0
        return false
    }

    function title(it) {
        if (root.kind === "images") return it.dangling ? i18n("untagged image") : it.ref
        return it.name
    }

    function subtitle(it) {
        if (root.kind === "images") {
            return [it.id, it.created, it.dangling ? "" : ""].filter(function (x) { return x !== "" }).join(" · ")
        }
        if (root.kind === "volumes") {
            return [it.driver, it.project !== "" ? i18n("project %1", it.project) : "",
                    it.links > 0 ? i18np("%1 container", "%1 containers", it.links) : ""]
                .filter(function (x) { return x !== "" }).join(" · ")
        }
        return [it.driver, it.scope, it.project !== "" ? i18n("project %1", it.project) : ""]
            .filter(function (x) { return x !== "" }).join(" · ")
    }

    function removable(it) {
        if (root.kind === "networks") return !it.builtin
        if (root.kind === "images") return it.containers === 0
        return it.links <= 0
    }

    function reload() { root.backend.fetchResources(root.kind) }

    onTabChanged: root.reload()
    Component.onCompleted: root.reload()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.ToolButton {
                id: backButton
                display: PlasmaComponents.AbstractButton.IconOnly
                icon.name: "go-previous"
                text: i18n("Back")
                onClicked: root.navigator.pop()
                PlasmaComponents.ToolTip { text: backButton.text }
            }

            Repeater {
                model: [i18n("Images"), i18n("Volumes"), i18n("Networks")]
                delegate: PlasmaComponents.ToolButton {
                    required property int index
                    required property string modelData
                    text: modelData
                    checkable: true
                    checked: root.tab === index
                    onClicked: root.tab = index
                }
            }

            Item { Layout.fillWidth: true }

            PlasmaComponents.CheckBox {
                visible: root.tab < 2
                text: i18n("Unused only")
                checked: root.unusedOnly
                onToggled: root.unusedOnly = checked
            }

            PlasmaComponents.BusyIndicator {
                visible: root.backend.resourcesBusy
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: implicitWidth
            }

            PlasmaComponents.ToolButton {
                id: reloadButton
                display: PlasmaComponents.AbstractButton.IconOnly
                icon.name: "view-refresh"
                text: i18n("Refresh")
                onClicked: root.reload()
                PlasmaComponents.ToolTip { text: reloadButton.text }
            }

            PlasmaComponents.ToolButton {
                id: pruneButton
                display: PlasmaComponents.AbstractButton.IconOnly
                icon.name: "edit-clear-history"
                text: i18n("Clean up unused data…")
                onClicked: root.dialogs.confirmPrune()
                PlasmaComponents.ToolTip { text: pruneButton.text }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.alpha(Kirigami.Theme.textColor, 0.2)
        }

        PlasmaComponents.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            background: null

            contentItem: ListView {
                id: view
                model: root.items
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                reuseItems: true

                delegate: PlasmaExtras.ListItem {
                    id: row
                    required property var modelData
                    width: view.width
                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing

                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    text: root.title(row.modelData)
                                    font.bold: true
                                    elide: Text.ElideMiddle
                                }

                                PlasmaComponents.Label {
                                    visible: root.isUnused(row.modelData)
                                    text: i18n("unused")
                                    color: Kirigami.Theme.neutralTextColor
                                    font: Kirigami.Theme.smallFont
                                }

                                PlasmaComponents.Label {
                                    visible: root.kind === "images" && row.modelData.containers > 0
                                    text: i18np("%1 container", "%1 containers", row.modelData.containers)
                                    color: Kirigami.Theme.positiveTextColor
                                    font: Kirigami.Theme.smallFont
                                }

                                PlasmaComponents.Label {
                                    visible: root.kind === "networks" && row.modelData.builtin
                                    text: i18n("built in")
                                    opacity: 0.6
                                    font: Kirigami.Theme.smallFont
                                }
                            }

                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: root.subtitle(row.modelData)
                                elide: Text.ElideRight
                                font: Kirigami.Theme.smallFont
                                opacity: 0.65
                            }
                        }

                        PlasmaComponents.Label {
                            visible: root.tab < 2
                            text: row.modelData.size || ""
                            font: Kirigami.Theme.smallFont
                            opacity: 0.8
                        }

                        PlasmaComponents.ToolButton {
                            id: removeButton
                            display: PlasmaComponents.AbstractButton.IconOnly
                            icon.name: "edit-delete"
                            text: i18n("Remove")
                            enabled: root.removable(row.modelData)
                            onClicked: root.dialogs.confirm(
                                i18n("Remove %1?", root.title(row.modelData)),
                                root.kind === "volumes"
                                    ? i18n("The volume and everything stored in it is deleted for good.")
                                    : i18n("This cannot be undone."),
                                function () { root.backend.removeResource(root.kind, row.modelData) })
                            PlasmaComponents.ToolTip { text: removeButton.text }
                        }
                    }
                }

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.gridUnit * 2
                    visible: view.count === 0 && !root.backend.resourcesBusy
                    text: root.unusedOnly ? i18n("Nothing unused") : i18n("Nothing here")
                    icon.name: "folder-open"
                }
            }
        }
    }
}
