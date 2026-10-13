import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

import "../components" as Components

/*
 * PopupView — the whole expanded UI, in a form that works unchanged both
 * inside the applet popup and inside the detached window.
 *
 * Layout:
 *   header      engine summary, search, view switcher, detail level, actions
 *   activity    thin bar showing time until the next poll
 *   error       inline message for the last failed command
 *   stack       home (list/table/compose) -> detail -> output
 *   status bar  running/stopped/images/cpu/mem totals
 *
 * It owns the view state (which view, how much detail, what search text) and
 * hands plain values down, so none of the pages below it need a back channel.
 */
PlasmaExtras.Representation {
    id: root

    required property var backend
    required property var applet

    readonly property var cfg: plasmoid.configuration

    property int viewMode: cfg.defaultViewMode
    property int detailLevel: cfg.defaultDetailLevel
    property string searchText: ""

    implicitWidth: Kirigami.Units.gridUnit * 36
    implicitHeight: Kirigami.Units.gridUnit * 24

    // ====================================================== filtering ====

    /*
     * One proxy feeds the list, the table and the compose groups, so the
     * search box and the column sort can never disagree with each other.
     * Filtering happens on a pre-joined searchKey (name + image + project +
     * ports + id) so "qbittorrent" finds a container however it is named.
     *
     * The proxy is the single owner of the sort order: the config seeds it,
     * and clicking a table header mutates it in place.
     */
    KItemModels.KSortFilterProxyModel {
        id: proxy
        sourceModel: root.backend.containerModel
        filterRoleName: "searchKey"
        filterRegularExpression: root.searchText.length > 0
            ? RegExp(root.searchText, "i")
            : RegExp("")
        filterCaseSensitivity: Qt.CaseInsensitive
        sortCaseSensitivity: Qt.CaseInsensitive
        recursiveFilteringEnabled: true
        dynamicSortFilter: true
        sortRoleName: root.cfg.sortRole
        sortOrder: root.cfg.sortAscending ? Qt.AscendingOrder : Qt.DescendingOrder
    }

    // ======================================================== actions ====

    function showDetail(recordId) {
        var page = stack.push(Qt.resolvedUrl("DetailPage.qml"), {
            "backend": root.backend,
            "dialogs": dialogs,
            "navigator": stack,
            "recordId": recordId
        })
        // The detail page raises this instead of holding a reference to the
        // stack, so it stays usable if the stack is ever re-parented (which is
        // exactly what detaching does).
        if (page) {
            page.outputRequested.connect(function (title, text, isLive) {
                root.showOutput(title, text, isLive, recordId)
            })
        }
    }

    /*
     * Opening output for a container that already has an output page on screen
     * updates that page instead of stacking a second copy on top of it.
     *
     * A reference is held rather than testing `stack.currentItem` for a
     * marker property: StackView types currentItem as a bare QQuickItem, so
     * reaching the OutputPage API through it is untyped, while a `var`
     * reference is checked by identity and stays honest.
     */
    property var outputPageRef: null

    function showOutput(title, text, isLive, recordId) {
        if (root.outputPageRef !== null && stack.currentItem === root.outputPageRef) {
            root.outputPageRef.setContent(title, text, isLive === true)
            root.outputPageRef.recordId = recordId || ""
            return
        }
        root.outputPageRef = stack.push(Qt.resolvedUrl("OutputPage.qml"), {
            "navigator": stack,
            "backend": root.backend,
            "pageTitle": title,
            "content": text,
            "live": isLive === true,
            "recordId": recordId || ""
        })
    }

    // ========================================================== chrome ====

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ------------------------------------------------ header -------
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            visible: root.cfg.showHeader
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: {
                    if (!root.backend.engineActive) return i18n("Docker is not running")
                    return i18np("%1 running · %2 total", "%1 running · %2 total",
                                 root.backend.running, root.backend.total)
                }
                font.bold: true
                elide: Text.ElideRight
                Layout.maximumWidth: Kirigami.Units.gridUnit * 12
                color: root.backend.engineActive
                    ? Kirigami.Theme.textColor
                    : Kirigami.Theme.negativeTextColor
            }

            PlasmaComponents.Label {
                visible: root.backend.unhealthy > 0 && root.cfg.showHealth
                text: i18np("%1 unhealthy", "%1 unhealthy", root.backend.unhealthy)
                color: Kirigami.Theme.negativeTextColor
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                elide: Text.ElideRight
            }

            Item { Layout.fillWidth: true }

            PlasmaExtras.SearchField {
                id: searchField
                Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                Layout.maximumWidth: Kirigami.Units.gridUnit * 14
                placeholderText: i18n("Search containers")
                onTextChanged: root.searchText = text
            }

            PlasmaComponents.ToolButton {
                icon.name: "view-list-tree"
                display: PlasmaComponents.AbstractButton.IconOnly
                checkable: true
                checked: root.viewMode === 0
                onClicked: root.viewMode = 0
                PlasmaComponents.ToolTip { text: i18n("Rows") }
            }

            PlasmaComponents.ToolButton {
                icon.name: "view-list-details"
                display: PlasmaComponents.AbstractButton.IconOnly
                checkable: true
                checked: root.viewMode === 1
                onClicked: root.viewMode = 1
                PlasmaComponents.ToolTip { text: i18n("Table") }
            }

            PlasmaComponents.ToolButton {
                icon.name: "folder"
                display: PlasmaComponents.AbstractButton.IconOnly
                checkable: true
                checked: root.viewMode === 2
                onClicked: root.viewMode = 2
                PlasmaComponents.ToolTip { text: i18n("Compose groups") }
            }

            PlasmaComponents.ToolButton {
                icon.name: "preferences-desktop-display"
                display: PlasmaComponents.AbstractButton.IconOnly
                visible: root.viewMode === 0
                onClicked: root.detailLevel = (root.detailLevel + 1) % 4
                PlasmaComponents.ToolTip {
                    text: i18n("Detail: %1",
                               ["minimal", "normal", "detailed", "verbose"][root.detailLevel])
                }
            }

            PlasmaComponents.BusyIndicator {
                visible: root.backend.refreshing && !root.backend.engineKnown
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: implicitWidth
            }

            PlasmaComponents.ToolButton {
                icon.name: "view-refresh"
                display: PlasmaComponents.AbstractButton.IconOnly
                enabled: !root.backend.refreshing
                onClicked: root.backend.refresh({
                    "force": true,
                    "withStats": true,
                    "withDisk": root.cfg.showDiskUsage
                })
                PlasmaComponents.ToolTip { text: i18n("Refresh") }
            }

            PlasmaComponents.ToolButton {
                icon.name: "window-pin"
                display: PlasmaComponents.AbstractButton.IconOnly
                onClicked: root.applet.toggleDetached()
                PlasmaComponents.ToolTip { text: i18n("Open in a separate window") }
            }

            PlasmaComponents.ToolButton {
                icon.name: "media-playback-start"
                display: PlasmaComponents.AbstractButton.IconOnly
                visible: !root.backend.engineActive
                onClicked: root.backend.startEngine()
                PlasmaComponents.ToolTip { text: i18n("Start the Docker service") }
            }

            PlasmaComponents.ToolButton {
                icon.name: "media-playback-stop"
                display: PlasmaComponents.AbstractButton.IconOnly
                visible: root.backend.engineActive
                onClicked: confirmStopEngine.open()
                PlasmaComponents.ToolTip { text: i18n("Stop the Docker service") }
            }
        }

        // --------------------------------------------- startup bar ------
        PlasmaComponents.ProgressBar {
            id: activityBar
            Layout.fillWidth: true
            visible: root.cfg.showActivityBar && root.backend.refreshing
                && !root.backend.engineKnown
            implicitHeight: visible ? Math.max(2, Kirigami.Units.smallSpacing / 2) : 0
            from: 0
            to: 100
            value: 50
            topInset: 0
            bottomInset: 0
        }

        // ------------------------------------------------- error --------
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            visible: text !== ""
            type: Kirigami.MessageType.Error
            text: root.backend.actionError || root.backend.lastError
            showCloseButton: true
        }

        // -------------------------------------------------- stack --------
        QQC2.StackView {
            id: stack
            Layout.fillWidth: true
            Layout.fillHeight: true
            initialItem: HomePage {
                backend: root.backend
                proxy: proxy
                dialogs: dialogs
                viewMode: root.viewMode
                detailLevel: root.detailLevel
                searchText: root.searchText
                onOpenDetail: function (recordId) { root.showDetail(recordId) }
                onOpenOutput: function (title, text, isLive, recordId) {
                    root.showOutput(title, text, isLive, recordId)
                }
            }
        }

        // --------------------------------------------- status bar --------
        Components.StatusBar {
            Layout.fillWidth: true
            visible: root.cfg.showStatusBar
            backend: root.backend
        }
    }


    /*
     * One set of confirmation dialogs for the whole view, living above
     * everything including the stack. A dialog owned by a delegate inside the
     * stack would be buried the moment a detail page is pushed on top of it.
     */
    Components.ActionDialogs {
        id: dialogs
        anchors.fill: parent
        backend: root.backend
    }

    // ------------------------------------------------------ dialogs ------

    QQC2.Dialog {
        id: confirmStopEngine
        title: i18n("Stop Docker?")
        modal: true
        anchors.centerIn: parent
        standardButtons: QQC2.Dialog.Yes | QQC2.Dialog.No
        onAccepted: root.backend.stopEngine()

        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            PlasmaExtras.Heading {
                Layout.fillWidth: true
                level: 3
                text: i18n("Stop the Docker service?")
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 22
                wrapMode: Text.WordWrap
                text: i18n("Every running container will be stopped. Services you depend on may go down.")
            }
        }
    }
}
