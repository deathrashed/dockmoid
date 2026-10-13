import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls

/*
 * Display settings: what the popup shows, and what the panel label shows.
 */
Kirigami.ScrollablePage {
    id: page

    property alias cfg_defaultViewMode: viewMode.currentIndex
    property alias cfg_defaultDetailLevel: detailLevel.currentIndex

    property alias cfg_showHeader: showHeader.checked
    property alias cfg_showStatusBar: showStatusBar.checked
    property alias cfg_showActivityBar: showActivityBar.checked
    property alias cfg_showHealth: showHealth.checked
    property alias cfg_showResourceBars: showResourceBars.checked
    property alias cfg_hideWhenInactive: hideWhenInactive.checked
    property alias cfg_rowIconSize: rowIconSize.value

    property alias cfg_separateResult: separateResult.checked
    property alias cfg_separator: separator.text
    property alias cfg_mainDot: mainDot.checked
    property alias cfg_mainDotColor: mainDotColor.color
    property alias cfg_mainDotUseCustomColor: mainDotUseCustomColor.checked
    property alias cfg_mainDotPosition: mainDotPosition.currentIndex
    property alias cfg_iconColor: iconColor.color
    property alias cfg_iconUseCustomColor: iconUseCustomColor.checked
    property alias cfg_wrapText: wrapText.checked
    property alias cfg_widthFit: widthFit.checked

    ColumnLayout {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        spacing: Kirigami.Units.smallSpacing

        // ------------------------------------------ popup --------------
        Kirigami.FormLayout {
            wideMode: false
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Popup")
            }
        }

        Kirigami.FormLayout {
            Controls.ComboBox {
                id: viewMode
                Kirigami.FormData.label: i18n("Default view: ")
                model: [i18n("Rows"), i18n("Table"), i18n("Compose groups")]
            }

            Controls.ComboBox {
                id: detailLevel
                Kirigami.FormData.label: i18n("Default row detail: ")
                model: [i18n("Minimal"), i18n("Normal"), i18n("Detailed"), i18n("Verbose")]
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Information
            text: i18n("Rows can be shown at four levels of detail, from a bare name up to id, project, network, I/O and uptime. The toolbar has a button that cycles through them. Table is a dense sortable grid; Compose groups buckets containers by their docker compose project, with start/stop/restart for the whole project.")
        }

        Kirigami.FormLayout {
            Controls.CheckBox {
                id: showHeader
                Kirigami.FormData.label: i18n("Show the toolbar: ")
            }

            Controls.CheckBox {
                id: showStatusBar
                Kirigami.FormData.label: i18n("Show the status bar: ")
            }

            Controls.CheckBox {
                id: showActivityBar
                Kirigami.FormData.label: i18n("Show startup loading bar: ")
            }

            Controls.CheckBox {
                id: showHealth
                Kirigami.FormData.label: i18n("Flag unhealthy containers: ")
            }

            Controls.CheckBox {
                id: showResourceBars
                Kirigami.FormData.label: i18n("Show CPU and memory bars: ")
            }

            Controls.SpinBox {
                id: rowIconSize
                Kirigami.FormData.label: i18n("Row icon size: ")
                from: 0
                to: 64
                stepSize: 2
                editable: true
                textFromValue: function (value) {
                    return value === 0
                        ? i18n("automatic")
                        : i18n("%1 px", value)
                }
                valueFromText: function (text) {
                    return parseInt(text) || 0
                }
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Information
            text: i18n("Health comes from the container's own healthcheck. Containers without one are left unmarked rather than shown as unknown, so a green dot always means something.")
        }

        // ------------------------------------------- panel --------------
        Kirigami.FormLayout {
            wideMode: false
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Panel")
            }
        }

        Kirigami.FormLayout {
            Controls.CheckBox {
                id: hideWhenInactive
                Kirigami.FormData.label: i18n("Hide the widget when Docker is not running: ")
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Icon color: ")
                Controls.CheckBox {
                    id: iconUseCustomColor
                }
                KQuickControls.ColorButton {
                    id: iconColor
                    enabled: iconUseCustomColor.checked
                }
            }

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                type: Kirigami.MessageType.Information
                text: i18n("The Docker mark is white by default. Enable the checkbox and choose any color for the panel icon. Container health remains visible in the list and status bar.")
            }
        }

        // ------------------------------------------ label --------------
        Kirigami.FormLayout {
            wideMode: false
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Panel label")
            }
        }

        Kirigami.FormLayout {
            Controls.CheckBox {
                id: separateResult
                Kirigami.FormData.label: i18n("Show running and total, e.g. 3~12: ")
            }

            Controls.TextField {
                id: separator
                Kirigami.FormData.label: i18n("Separator: ")
                visible: separateResult.checked
            }

            Controls.CheckBox {
                id: mainDot
                Kirigami.FormData.label: i18n("Show a dot instead of a number: ")
                onCheckedChanged: if (checked) separateResult.checked = false
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Dot options: ")
                visible: mainDot.checked

                Controls.CheckBox {
                    id: mainDotUseCustomColor
                }

                KQuickControls.ColorButton {
                    id: mainDotColor
                    enabled: mainDotUseCustomColor.checked
                }

                Controls.ComboBox {
                    id: mainDotPosition
                    model: [i18n("Top Right"), i18n("Top Left"), i18n("Bottom Right"), i18n("Bottom Left")]
                }
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Information
            text: i18n("The dot is only drawn when at least one container is running. In the default label mode the badge follows the icon size; 'Wrap text' lets it wrap, and 'Fit width' expands it to the text.")
        }

        Kirigami.FormLayout {
            Controls.CheckBox {
                id: wrapText
                Kirigami.FormData.label: i18n("Wrap the badge text: ")
                onCheckedChanged: if (checked) widthFit.checked = false
            }

            Controls.CheckBox {
                id: widthFit
                Kirigami.FormData.label: i18n("Fit the badge to the text: ")
                onCheckedChanged: if (checked) wrapText.checked = false
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
