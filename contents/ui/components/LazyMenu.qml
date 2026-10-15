import QtQuick

/*
 * LazyMenu — a menu that is built the first time it is shown.
 *
 * A Plasma menu with a few dozen entries costs several hundred QML objects. The
 * popup carried half a dozen of them from the first frame; opening one is rare.
 * Give `menu` the Menu as a Component; popup() and opened work as on the menu.
 */
Item {
    id: host
    property Component menu
    readonly property bool opened: loader.item ? (loader.item as Menu).opened : false
    width: 0
    height: 0

    function popup(anchor, x, y) {
        loader.active = true
        if (loader.item) (loader.item as Menu).popup(anchor, x, y)
    }
    function close() { if (loader.item) (loader.item as Menu).close() }

    Loader { id: loader; active: false; sourceComponent: host.menu }
}
