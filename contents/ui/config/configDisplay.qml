import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQuickControls

/*
 * Display: what the popup shows, and what the panel icon and label show.
 */
KCM.SimpleKCM {
    id: page

    property alias cfg_defaultViewMode: viewMode.currentIndex
    property alias cfg_defaultDetailLevel: detailLevel.currentIndex
    property alias cfg_showHeader: showHeader.checked
    property alias cfg_showStatusBar: showStatusBar.checked
    property alias cfg_showActivityBar: showActivityBar.checked
    property alias cfg_showHealth: showHealth.checked
    property alias cfg_showRestartPolicy: showRestartPolicy.checked
    property alias cfg_showResourceBars: showResourceBars.checked
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
    property alias cfg_separator: separator.text
    property alias cfg_mainDot: mainDot.checked
    property alias cfg_mainDotColor: mainDotColor.color
    property alias cfg_mainDotUseCustomColor: mainDotUseCustomColor.checked
    property alias cfg_mainDotPosition: mainDotPosition.currentIndex
    property alias cfg_wrapText: wrapText.checked
    property alias cfg_widthFit: widthFit.checked

    Kirigami.FormLayout {
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Popup")
        }

        Controls.ComboBox {
            id: viewMode
            Kirigami.FormData.label: i18n("Open with:")
            model: [i18n("List"), i18n("Table"), i18n("Grouped by Compose project")]
        }

        Controls.ComboBox {
            id: detailLevel
            Kirigami.FormData.label: i18n("List detail:")
            model: [i18n("Minimal"), i18n("Normal"), i18n("Detailed"), i18n("Everything")]
        }
        Hint { text: i18n("From just a name up to ids, networks, I/O and uptime. The eye button in the toolbar changes it on the fly.") }

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
        Controls.CheckBox {
            id: showResourceBars
            text: i18n("CPU and memory with bars")
        }
        Hint { text: i18n("Health comes from the container's own healthcheck. Containers without one are left unmarked, so a green dot always means something.") }

        Controls.SpinBox {
            id: rowIconSize
            Kirigami.FormData.label: i18n("Icon size:")
            from: 0; to: 64; stepSize: 2; editable: true
            textFromValue: function (v) { return v === 0 ? i18n("automatic") : i18n("%1 px", v) }
            valueFromText: function (t) { return parseInt(t) || 0 }
        }

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
            model: [i18n("Refresh now"), i18n("Open the separate window"),
                    i18n("Restart unhealthy containers"), i18n("Do nothing")]
        }

        Controls.ComboBox {
            id: indicator
            Kirigami.FormData.label: i18n("Ring:")
            model: [i18n("Fills like a gauge"), i18n("One solid colour"), i18n("Never changes")]
        }

        Controls.ComboBox {
            id: indicatorTarget
            Kirigami.FormData.label: i18n("State colour goes to:")
            model: [i18n("The ring"), i18n("The whale"), i18n("Both")]
        }
        Hint { text: i18n("Blue while things run normally, amber when something is paused, red when something is wrong. A paused or unhealthy stack fills the whole ring. With “The whale”, the ring stays your logo colour and only shows how many are running. The logo dims when Docker is down or nothing runs.") }

        RowLayout {
            Kirigami.FormData.label: i18n("State colours:")
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
        Hint { text: i18n("Left to right: running normally, paused, wrong. Off uses blue, and your theme's amber and red.") }

        RowLayout {
            Kirigami.FormData.label: i18n("Logo colour:")
            Controls.CheckBox {
                id: iconUseCustomColor
                text: i18n("use")
            }
            KQuickControls.ColorButton {
                id: iconColor
                enabled: iconUseCustomColor.checked
            }
        }
        Hint { text: i18n("The logo and the gauge track are white by default, which suits dark panels. Pick another colour for a light panel.") }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Panel label")
        }

        Controls.CheckBox {
            id: separateResult
            Kirigami.FormData.label: i18n("Badge:")
            text: i18n("show running and total, like 3~12")
        }

        Controls.TextField {
            id: separator
            Kirigami.FormData.label: i18n("Separator:")
            visible: separateResult.checked
            maximumLength: 3
        }

        Controls.CheckBox {
            id: mainDot
            text: i18n("a dot instead of a number")
            onCheckedChanged: if (checked) separateResult.checked = false
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Dot:")
            visible: mainDot.checked
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
        Hint {
            visible: mainDot.checked
            text: i18n("The dot only shows while at least one container is running.")
        }

        Controls.CheckBox {
            id: wrapText
            Kirigami.FormData.label: i18n("Badge text:")
            text: i18n("wrap")
            onCheckedChanged: if (checked) widthFit.checked = false
        }
        Controls.CheckBox {
            id: widthFit
            text: i18n("grow to fit")
            onCheckedChanged: if (checked) wrapText.checked = false
        }
    }
}
