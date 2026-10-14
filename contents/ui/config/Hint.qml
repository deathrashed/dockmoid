import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

/* Inline contextual help for a settings control. */
Kirigami.ContextualHelpButton {
    property string helpText: ""
    toolTipText: helpText
    Layout.preferredWidth: Kirigami.Units.iconSizes.small
    Layout.preferredHeight: Kirigami.Units.iconSizes.small
}
