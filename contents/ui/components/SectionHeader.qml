import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/style.js" as Style

/*
 * SectionHeader — the bar that titles a collapsible section.
 *
 * One look and one disclosure pattern everywhere: a chevron that points down
 * when the section is open and right when it is closed, and a title that
 * toggles it too. Extra controls (a view choice, a density button) go between
 * the title and the chevron by declaring them as children.
 */
Item {
    id: root

    property string title: ""
    property string glyph: ""
    property color glyphColor: Kirigami.Theme.textColor
    property bool expanded: true
    property bool collapsible: true
    /* Draw a framed bar, for headers inside a scrolling page. */
    property bool framed: false
    default property alias trailing: extras.data
    signal toggled()

    implicitHeight: Kirigami.Units.gridUnit * 2.1
    Layout.fillWidth: true

    Rectangle {
        anchors.fill: parent
        visible: root.framed
        radius: Kirigami.Units.smallSpacing
        color: root.expanded ? Qt.alpha(Kirigami.Theme.highlightColor, Style.ALPHA.tintStrong)
                             : Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface2)
        border.color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.borderFaint)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        Item {
            id: titleArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            Accessible.role: Accessible.Button
            Accessible.name: root.title
            Accessible.onPressAction: if (root.collapsible) root.toggled()

            RowLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing
                ActionIcon {
                    visible: root.glyph !== ""
                    glyph: root.glyph
                    color: root.glyphColor
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: implicitWidth
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: root.title
                    font.bold: true
                    elide: Text.ElideRight
                }
            }
            HoverHandler { cursorShape: root.collapsible ? Qt.PointingHandCursor : Qt.ArrowCursor }
            TapHandler { enabled: root.collapsible; onTapped: root.toggled() }
        }

        RowLayout {
            id: extras
            spacing: Kirigami.Units.smallSpacing
        }

        ActionToolButton {
            visible: root.collapsible
            glyph: root.expanded ? "chevron-down" : "go-next"
            text: root.expanded ? i18n("Collapse %1", root.title) : i18n("Expand %1", root.title)
            onClicked: root.toggled()
        }
    }
}
