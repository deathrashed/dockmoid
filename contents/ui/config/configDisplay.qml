import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQuickControls
import ".." as Widget

/*
 * Display: what the popup shows, and what the panel icon and label show.
 */
KCM.SimpleKCM {
    id: page

    property int currentTab: 0

    header: Kirigami.NavigationTabBar {
        objectName: "settingsTabs"
        actions: [
            Kirigami.Action {
                icon.name: "view-list-details"
                text: i18n("Popup")
                checked: page.currentTab === 0
                onTriggered: page.currentTab = 0
            },
            Kirigami.Action {
                icon.name: "view-list-icons"
                text: i18n("Panel")
                checked: page.currentTab === 1
                onTriggered: page.currentTab = 1
            },
            Kirigami.Action {
                icon.name: "view-list-details"
                text: i18n("Containers")
                checked: page.currentTab === 2
                onTriggered: page.currentTab = 2
            },
            Kirigami.Action {
                icon.name: "preferences-desktop-icons"
                text: i18n("Icons")
                checked: page.currentTab === 3
                onTriggered: page.currentTab = 3
            }
        ]
    }
    property int cfg_defaultViewModeDefault
    property int cfg_defaultGridDetailLevelDefault
    property int cfg_defaultTableDetailLevelDefault
    property int cfg_resourceBarMaxDefault
    property int cfg_panelStyleDefault
    property int cfg_defaultDetailLevelDefault
    property bool cfg_showHeaderDefault
    property bool cfg_showStatusBarDefault
    property bool cfg_showActivityBarDefault
    property bool cfg_showHealthDefault
    property bool cfg_showRestartPolicyDefault
    property bool cfg_showResourceBarsDefault
    property int cfg_rowIconSizeDefault
    property bool cfg_hideWhenInactiveDefault
    property int cfg_middleClickActionDefault
    property int cfg_panelIndicatorDefault
    property int cfg_indicatorTargetDefault
    property bool cfg_customStateColorsDefault
    property string cfg_stateOkColorDefault
    property string cfg_stateBadColorDefault
    property string cfg_statePausedColorDefault
    property string cfg_iconColorDefault
    property bool cfg_iconUseCustomColorDefault
    property bool cfg_separateResultDefault
    property int cfg_badgeStyleDefault
    property string cfg_separatorDefault
    property bool cfg_mainDotDefault
    property string cfg_mainDotColorDefault
    property bool cfg_mainDotUseCustomColorDefault
    property int cfg_mainDotPositionDefault
    property bool cfg_wrapTextDefault
    property bool cfg_widthFitDefault
    property int cfg_toolbarStyleDefault
    property int cfg_popupWidthDefault
    property int cfg_popupHeightDefault
    property string cfg_serviceIconDirectoryDefault
    property bool cfg_coloredServiceIconsDefault
    property int cfg_iconVariantDefault
    property string cfg_customIconsDefault
    property string cfg_customIconFilesDefault


    property alias cfg_defaultViewMode: viewMode.currentIndex
    property alias cfg_defaultDetailLevel: detailLevel.currentIndex
    property alias cfg_showHeader: showHeader.checked
    property alias cfg_showStatusBar: showStatusBar.checked
    property alias cfg_showActivityBar: showActivityBar.checked
    property alias cfg_showHealth: showHealth.checked
    property alias cfg_showRestartPolicy: showRestartPolicy.checked
    property alias cfg_showResourceBars: showResourceBars.checked
    property alias cfg_defaultGridDetailLevel: gridDetail.currentIndex
    property alias cfg_defaultTableDetailLevel: tableDetail.currentIndex
    property alias cfg_resourceBarMax: resourceScale.value
    property alias cfg_panelStyle: panelStyle.currentIndex
    property alias cfg_rowIconSize: rowIconSize.value
    property alias cfg_hideWhenInactive: hideWhenInactive.checked
    property alias cfg_middleClickAction: middleClick.currentIndex
    property alias cfg_panelIndicator: indicator.currentIndex
    property alias cfg_indicatorTarget: indicatorTarget.currentIndex
    property alias cfg_customStateColors: customStates.checked
    property alias cfg_stateOkColor: okColor.color
    property alias cfg_stateBadColor: badColor.color
    property alias cfg_statePausedColor: pausedColor.color
    property alias cfg_iconColor: iconColor.color
    property alias cfg_iconUseCustomColor: iconUseCustomColor.checked
    property alias cfg_separateResult: separateResult.checked
    property alias cfg_badgeStyle: badgeStyle.currentIndex
    property alias cfg_separator: separator.text
    property alias cfg_mainDot: mainDot.checked
    property alias cfg_mainDotColor: mainDotColor.color
    property alias cfg_mainDotUseCustomColor: mainDotUseCustomColor.checked
    property alias cfg_mainDotPosition: mainDotPosition.currentIndex
    property alias cfg_wrapText: wrapText.checked
    property alias cfg_widthFit: widthFit.checked
    property alias cfg_toolbarStyle: toolbarStyle.currentIndex
    property alias cfg_popupWidth: popupWidth.value
    property alias cfg_popupHeight: popupHeight.value

    property string cfg_serviceIconDirectory: ""
    property bool cfg_coloredServiceIcons: true
    property int cfg_iconVariant: 0
    property string cfg_customIcons: ""
    property string cfg_customIconFiles: "{}"
    property string cfg_engineCommand: plasmoid.configuration.engineCommand || "docker"
    property string cfg_activeContext: plasmoid.configuration.activeContext || ""
    readonly property var iconSettings: iconsPage.item

    onCfg_serviceIconDirectoryChanged: if (iconSettings && iconSettings.cfg_serviceIconDirectory !== cfg_serviceIconDirectory) iconSettings.cfg_serviceIconDirectory = cfg_serviceIconDirectory
    onCfg_coloredServiceIconsChanged: if (iconSettings && iconSettings.cfg_coloredServiceIcons !== cfg_coloredServiceIcons) iconSettings.cfg_coloredServiceIcons = cfg_coloredServiceIcons
    onCfg_iconVariantChanged: if (iconSettings && iconSettings.cfg_iconVariant !== cfg_iconVariant) iconSettings.cfg_iconVariant = cfg_iconVariant
    onCfg_customIconsChanged: if (iconSettings && iconSettings.cfg_customIcons !== cfg_customIcons) iconSettings.cfg_customIcons = cfg_customIcons
    onCfg_customIconFilesChanged: if (iconSettings && iconSettings.cfg_customIconFiles !== cfg_customIconFiles) iconSettings.cfg_customIconFiles = cfg_customIconFiles

    readonly property bool iconPanelStyle: panelStyle.currentIndex === 0 || panelStyle.currentIndex === 1 || panelStyle.currentIndex === 5
    readonly property var panelPreviewConfiguration: ({
        panelStyle: page.cfg_panelStyle,
        badgeStyle: page.cfg_badgeStyle,
        customStateColors: page.cfg_customStateColors,
        iconColor: page.cfg_iconColor,
        iconUseCustomColor: page.cfg_iconUseCustomColor,
        indicatorTarget: page.cfg_indicatorTarget,
        mainDot: page.cfg_mainDot,
        mainDotColor: page.cfg_mainDotColor,
        mainDotPosition: page.cfg_mainDotPosition,
        mainDotUseCustomColor: page.cfg_mainDotUseCustomColor,
        middleClickAction: page.cfg_middleClickAction,
        panelIndicator: page.cfg_panelIndicator,
        separateResult: page.cfg_separateResult,
        separator: page.cfg_separator,
        stateBadColor: page.cfg_stateBadColor,
        stateOkColor: page.cfg_stateOkColor,
        statePausedColor: page.cfg_statePausedColor,
        widthFit: page.cfg_widthFit,
        wrapText: page.cfg_wrapText
    })

    ColumnLayout {
        anchors.left: parent.left; anchors.right: parent.right
        Kirigami.FormLayout { Layout.fillWidth: true; Layout.maximumWidth: Kirigami.Units.gridUnit * 42; Layout.alignment: Qt.AlignHCenter; wideMode: width >= Kirigami.Units.gridUnit * 26; visible: page.currentTab === 0

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Popup")
        }

        Controls.ComboBox {
            id: viewMode
            Kirigami.FormData.label: i18n("Open with:")
            model: [i18n("List"), i18n("Table"), i18n("Groups"), i18n("Grid")]
        }

        Controls.ComboBox {
            id: detailLevel
            Kirigami.FormData.label: i18n("List detail:")
            model: [i18n("Minimal"), i18n("Normal"), i18n("Detailed"), i18n("Verbose")]
        }
        Controls.ComboBox {
            id: gridDetail
            Kirigami.FormData.label: i18n("Grid detail:")
            model: [i18n("Minimal"), i18n("Normal"), i18n("Detailed"), i18n("Verbose")]
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Table detail:")
            Controls.ComboBox {
                id: tableDetail

                model: [i18n("Minimal"), i18n("Normal"), i18n("Detailed"), i18n("Verbose")]
            }
            QuestionHelp { helpText: i18n("Each view keeps its own detail level. Minimal shows identity and status; Verbose adds metadata and quick actions. The eye button changes the current view.") }
        }

        Controls.CheckBox {
            id: showHeader
            Kirigami.FormData.label: i18n("Show:")
            text: i18n("toolbar")
        }
        Controls.CheckBox {
            id: showStatusBar
            text: i18n("status bar")
        }
        Controls.CheckBox {
            id: showActivityBar
            text: i18n("loading bar on first start")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Toolbar buttons:")
            Controls.ComboBox {
                id: toolbarStyle

                model: [i18n("Icons only"), i18n("Text beside icons"), i18n("Text only"), i18n("Text below icons")]
            }
            QuestionHelp { helpText: i18n("Choose how toolbar actions are labelled in the popup.") }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Popup window")
        }
        Controls.SpinBox {
            id: popupWidth
            Kirigami.FormData.label: i18n("Width:")
            from: 396; to: 3840; stepSize: 1; editable: true
            textFromValue: function (v) { return i18n("%1 px", v) }
            valueFromText: function (t) { return parseInt(t) || 648 }
        }
        Controls.SpinBox {
            id: popupHeight
            Kirigami.FormData.label: i18n("Height:")
            from: 252; to: 2160; stepSize: 1; editable: true
            textFromValue: function (v) { return i18n("%1 px", v) }
            valueFromText: function (t) { return parseInt(t) || 432 }
        }


        Controls.Button { text: i18n("Restore defaults"); icon.name: "edit-undo"; onClicked: { page.cfg_defaultViewMode = page.cfg_defaultViewModeDefault; page.cfg_defaultDetailLevel = page.cfg_defaultDetailLevelDefault; page.cfg_showHeader = page.cfg_showHeaderDefault; page.cfg_showStatusBar = page.cfg_showStatusBarDefault; page.cfg_showActivityBar = page.cfg_showActivityBarDefault; page.cfg_showHealth = page.cfg_showHealthDefault; page.cfg_showRestartPolicy = page.cfg_showRestartPolicyDefault; page.cfg_showResourceBars = page.cfg_showResourceBarsDefault; page.cfg_rowIconSize = page.cfg_rowIconSizeDefault; page.cfg_resourceBarMax = page.cfg_resourceBarMaxDefault; page.cfg_defaultGridDetailLevel = page.cfg_defaultGridDetailLevelDefault; page.cfg_defaultTableDetailLevel = page.cfg_defaultTableDetailLevelDefault; page.cfg_toolbarStyle = page.cfg_toolbarStyleDefault; page.cfg_popupWidth = page.cfg_popupWidthDefault; page.cfg_popupHeight = page.cfg_popupHeightDefault } }
        }
        Kirigami.FormLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 42
            Layout.alignment: Qt.AlignHCenter
            wideMode: width >= Kirigami.Units.gridUnit * 26
            visible: page.currentTab === 2
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Containers")
        }

        Controls.CheckBox {
            id: showHealth
            Kirigami.FormData.label: i18n("Mark:")
            text: i18n("unhealthy containers")
        }
        Controls.CheckBox {
            id: showRestartPolicy
            text: i18n("containers Docker starts automatically")
        }
        RowLayout {
            Controls.CheckBox {
                id: showResourceBars
                text: i18n("CPU and memory with bars")
            }
            QuestionHelp { helpText: i18n("Health comes from the container's own healthcheck. Containers without one are left unmarked, so a green dot always means something.") }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Usage bar full scale:")
            Controls.SpinBox {
                id: resourceScale

                enabled: showResourceBars.checked
                from: 5; to: 5; editable: false
                textFromValue: function(v) { return i18n("%1%", v) }
                valueFromText: function(t) { return parseInt(t) || 5 }
            }
            QuestionHelp { helpText: i18n("Container bars use a 0–5% scale; footer bars use 0–20%. Percentage labels always show actual usage, including values above the bar scale.") }
        }
        Controls.SpinBox {
            id: rowIconSize
            Kirigami.FormData.label: i18n("Icon size:")
            from: 0; to: 64; stepSize: 2; editable: true
            textFromValue: function (v) { return v === 0 ? i18n("automatic") : i18n("%1 px", v) }
            valueFromText: function (t) { return parseInt(t) || 0 }
        }


        Controls.Button { text: i18n("Restore defaults"); icon.name: "edit-undo"; onClicked: { page.cfg_defaultViewMode = page.cfg_defaultViewModeDefault; page.cfg_defaultDetailLevel = page.cfg_defaultDetailLevelDefault; page.cfg_showHeader = page.cfg_showHeaderDefault; page.cfg_showStatusBar = page.cfg_showStatusBarDefault; page.cfg_showActivityBar = page.cfg_showActivityBarDefault; page.cfg_showHealth = page.cfg_showHealthDefault; page.cfg_showRestartPolicy = page.cfg_showRestartPolicyDefault; page.cfg_showResourceBars = page.cfg_showResourceBarsDefault; page.cfg_rowIconSize = page.cfg_rowIconSizeDefault; page.cfg_resourceBarMax = page.cfg_resourceBarMaxDefault; page.cfg_defaultGridDetailLevel = page.cfg_defaultGridDetailLevelDefault; page.cfg_defaultTableDetailLevel = page.cfg_defaultTableDetailLevelDefault; page.cfg_toolbarStyle = page.cfg_toolbarStyleDefault; page.cfg_popupWidth = page.cfg_popupWidthDefault; page.cfg_popupHeight = page.cfg_popupHeightDefault } }
        }
        Kirigami.FormLayout { Layout.fillWidth: true; Layout.maximumWidth: Kirigami.Units.gridUnit * 42; Layout.alignment: Qt.AlignHCenter; wideMode: width >= Kirigami.Units.gridUnit * 26; visible: page.currentTab === 1
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Panel icon")
        }

        Controls.CheckBox {
            id: hideWhenInactive
            Kirigami.FormData.label: i18n("Hide:")
            text: i18n("when Docker is not running")
        }

        Controls.ComboBox {
            id: middleClick
            Kirigami.FormData.label: i18n("Middle click:")
            model: [i18n("Refresh now"), i18n("Attach or detach the window"),
                    i18n("Restart unhealthy containers"), i18n("Do nothing")]
        }

        Controls.ComboBox {
            id: panelStyle
            Kirigami.FormData.label: i18n("Display style:")
            model: [i18n("Ring gauge"), i18n("Whale icon"), i18n("Running count"), i18n("Running / total"), i18n("Count with segments"), i18n("Whale with progress bar"), i18n("Ring with attention")]
        }
        RowLayout {
            Controls.Frame {
                Layout.fillWidth: true
                Kirigami.FormData.isSection: true
                RowLayout {
                    anchors.fill: parent
                    Widget.Compact {
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: 56
                        previewMode: true
                        configuration: page.panelPreviewConfiguration
                        applet: null
                        backend: QtObject {
                            property bool engineKnown: true
                            property bool engineActive: true
                            property int running: 3
                            property int total: 5
                            property int unhealthy: 0
                            property int problemCount: 0
                            property int pausedCount: 0
                        }
                    }
                    Controls.Label { Layout.fillWidth: true; text: i18n("Live panel preview\n3 running · 2 stopped"); wrapMode: Text.Wrap }
                }
            }
            QuestionHelp { helpText: i18n("Use an icon, a clear number, or a running-container meter. Colours still show connection and health problems. Hover for full counts and usage.") }
            QuestionHelp { visible: panelStyle.currentIndex === 6; helpText: i18n("The ring stays clean during normal operation. A warning appears only when Docker is down or a container is paused or unhealthy.") }
        }
        Controls.ComboBox {
            id: indicator
            visible: panelStyle.currentIndex === 0
            Kirigami.FormData.label: i18n("Ring:")
            model: [i18n("Fills like a gauge"), i18n("One solid colour"), i18n("Never changes")]
        }

        RowLayout {
            Kirigami.FormData.label: i18n("State colour goes to:")
            Controls.ComboBox {
                id: indicatorTarget
                visible: panelStyle.currentIndex === 0

                model: [i18n("The ring"), i18n("The whale"), i18n("Both")]
            }
            QuestionHelp { helpText: i18n("Blue while things run normally, amber when something is paused, red when something is wrong. A paused or unhealthy stack fills the whole ring. With “The whale”, the ring stays your logo colour and only shows how many are running. The logo dims when Docker is down or nothing runs.") }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("State colours:")
            RowLayout {

                enabled: true
                Controls.CheckBox {
                    id: customStates
                    text: i18n("custom")
                }
                KQuickControls.ColorButton {
                    id: okColor
                    enabled: customStates.checked
                    Controls.ToolTip.text: i18n("All well"); Controls.ToolTip.visible: hovered
                }
                KQuickControls.ColorButton {
                    id: pausedColor
                    enabled: customStates.checked
                    Controls.ToolTip.text: i18n("Something paused"); Controls.ToolTip.visible: hovered
                }
                KQuickControls.ColorButton {
                    id: badColor
                    enabled: customStates.checked
                    Controls.ToolTip.text: i18n("Something wrong"); Controls.ToolTip.visible: hovered
                }
            }
            QuestionHelp { helpText: i18n("Left to right: running, paused, needs attention. Disable custom colours to use Dockmoid blue and theme warning colours.") }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Logo colour:")
            RowLayout {

                Controls.CheckBox {
                    id: iconUseCustomColor
                    text: i18n("use")
                }
                KQuickControls.ColorButton {
                    id: iconColor
                    enabled: iconUseCustomColor.checked
                }
            }
            QuestionHelp { helpText: i18n("The logo and track follow your theme text colour. Override it here; status colours are configured above.") }
        }

        Kirigami.Separator {
            visible: page.iconPanelStyle
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Panel label")
        }

        Controls.ComboBox {
            id: badgeStyle
            visible: page.iconPanelStyle && !mainDot.checked
            Kirigami.FormData.label: i18n("Badge:")
            model: [i18n("Custom counts"), i18n("Running / total"),
                    i18n("Running count"), i18n("Percent running"), i18n("Running label")]
        }
        Controls.CheckBox {
            id: separateResult
            visible: page.iconPanelStyle && !mainDot.checked && badgeStyle.currentIndex === 0
            text: i18n("show running and total")
        }

        Controls.TextField {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            id: separator
            Kirigami.FormData.label: i18n("Separator:")
            visible: page.iconPanelStyle && !mainDot.checked && badgeStyle.currentIndex === 0 && separateResult.checked
            maximumLength: 3
        }

        Controls.CheckBox {
            id: mainDot
            visible: page.iconPanelStyle
            text: i18n("Show a status dot instead of a badge")
            onCheckedChanged: if (checked) separateResult.checked = false
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Dot:")
            RowLayout {

                visible: page.iconPanelStyle && mainDot.checked
                Controls.CheckBox {
                    id: mainDotUseCustomColor
                    text: i18n("custom colour")
                }
                KQuickControls.ColorButton {
                    id: mainDotColor
                    enabled: mainDotUseCustomColor.checked
                }
                Controls.ComboBox {
                    id: mainDotPosition
                    model: [i18n("Top right"), i18n("Top left"), i18n("Bottom right"), i18n("Bottom left")]
                }
            }
            QuestionHelp {
                visible: page.iconPanelStyle && mainDot.checked
                helpText: i18n("The dot only shows while at least one container is running.")
            }
        }

        Controls.CheckBox {
            id: wrapText
            visible: page.iconPanelStyle && !mainDot.checked
            Kirigami.FormData.label: i18n("Badge text:")
            text: i18n("wrap")
            onCheckedChanged: if (checked) widthFit.checked = false
        }
        Controls.CheckBox {
            id: widthFit
            visible: page.iconPanelStyle && !mainDot.checked
            text: i18n("fit the full label")
            onCheckedChanged: if (checked) wrapText.checked = false
        }Controls.Button { text: i18n("Restore defaults"); icon.name: "edit-undo"; onClicked: { page.cfg_panelStyle = page.cfg_panelStyleDefault; page.cfg_hideWhenInactive = page.cfg_hideWhenInactiveDefault; page.cfg_middleClickAction = page.cfg_middleClickActionDefault; page.cfg_panelIndicator = page.cfg_panelIndicatorDefault; page.cfg_indicatorTarget = page.cfg_indicatorTargetDefault; page.cfg_customStateColors = page.cfg_customStateColorsDefault; page.cfg_stateOkColor = page.cfg_stateOkColorDefault; page.cfg_statePausedColor = page.cfg_statePausedColorDefault; page.cfg_stateBadColor = page.cfg_stateBadColorDefault; page.cfg_iconUseCustomColor = page.cfg_iconUseCustomColorDefault; page.cfg_iconColor = page.cfg_iconColorDefault; page.cfg_separateResult = page.cfg_separateResultDefault; page.cfg_badgeStyle = page.cfg_badgeStyleDefault; page.cfg_separator = page.cfg_separatorDefault; page.cfg_mainDot = page.cfg_mainDotDefault; page.cfg_mainDotUseCustomColor = page.cfg_mainDotUseCustomColorDefault; page.cfg_mainDotColor = page.cfg_mainDotColorDefault; page.cfg_mainDotPosition = page.cfg_mainDotPositionDefault; page.cfg_wrapText = page.cfg_wrapTextDefault; page.cfg_widthFit = page.cfg_widthFitDefault } }
        }

        Loader {
            id: iconsPage
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 42
            Layout.alignment: Qt.AlignHCenter
            active: true
            visible: page.currentTab === 3
            source: "configServices.qml"
            onLoaded: {
                var services = page.iconSettings
                services.cfg_serviceIconDirectory = page.cfg_serviceIconDirectory
                services.cfg_coloredServiceIcons = page.cfg_coloredServiceIcons
                services.cfg_iconVariant = page.cfg_iconVariant
                services.cfg_customIcons = page.cfg_customIcons
                services.cfg_customIconFiles = page.cfg_customIconFiles
            }
            Binding { target: page.iconSettings; property: "cfg_serviceIconDirectoryDefault"; value: page.cfg_serviceIconDirectoryDefault }
            Binding { target: page.iconSettings; property: "cfg_coloredServiceIconsDefault"; value: page.cfg_coloredServiceIconsDefault }
            Binding { target: page.iconSettings; property: "cfg_iconVariantDefault"; value: page.cfg_iconVariantDefault }
            Binding { target: page.iconSettings; property: "cfg_customIconsDefault"; value: page.cfg_customIconsDefault }
            Binding { target: page.iconSettings; property: "cfg_customIconFilesDefault"; value: page.cfg_customIconFilesDefault }
            Binding { target: page.iconSettings; property: "cfg_engineCommand"; value: page.cfg_engineCommand }
            Binding { target: page.iconSettings; property: "cfg_activeContext"; value: page.cfg_activeContext }
            Connections {
                target: page.iconSettings
                function onCfg_serviceIconDirectoryChanged() { page.cfg_serviceIconDirectory = page.iconSettings.cfg_serviceIconDirectory }
                function onCfg_coloredServiceIconsChanged() { page.cfg_coloredServiceIcons = page.iconSettings.cfg_coloredServiceIcons }
                function onCfg_iconVariantChanged() { page.cfg_iconVariant = page.iconSettings.cfg_iconVariant }
                function onCfg_customIconsChanged() { page.cfg_customIcons = page.iconSettings.cfg_customIcons }
                function onCfg_customIconFilesChanged() { page.cfg_customIconFiles = page.iconSettings.cfg_customIconFiles }
            }
        }


    }
}
