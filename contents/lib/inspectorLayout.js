.pragma library

/*
 * inspectorLayout.js — the inspector's rules: which page it shows, whether it
 * is shown, and where it sits (below the list, or beside it when asked and
 * there is room). Pure functions over the stored `dock` object, so the rules
 * can be tested without QML. The caller persists what the transitions return.
 *
 * The stored dock (any key may be missing):
 *   page        "preview" | "logs" | "events" | "compose" | "health"
 *   expanded    the pane is shown (default true); hidden, only its tab strip shows
 *   side        beside the list rather than below it
 *   width       the pane's width side by side
 *   height_<page>  the pane's height below the list, one per page
 *   previewMode "selection" | "hover" | "off" (read by the QML side)
 *
 * Transitions return a new dock object and keep keys they do not change.
 */
var PAGES = ["preview", "logs", "events", "compose", "health"]
/* SplitView's "no limit". */
var UNLIMITED = 16777215

function stored(dock) { return dock && typeof dock === "object" ? dock : {} }
function setting(dock, key, fallback) { var d = stored(dock); return d[key] === undefined ? fallback : d[key] }
function changed(dock, values) {
    var next = {}, d = stored(dock), key
    for (key in d) next[key] = d[key]
    for (key in values) next[key] = values[key]
    return next
}

/* What the stored dock says, with defaults. Older settings may name a page
   that moved to the toolbar; those show Overview. */
function normalize(dock) {
    var page = String(setting(dock, "page", "preview"))
    return {
        page: PAGES.indexOf(page) >= 0 ? page : "preview",
        shown: setting(dock, "expanded", true) === true,
        side: setting(dock, "side", false) === true
    }
}

/* A strip tab: the open tab while shown hides the pane; any other opens its page. */
function pressTab(dock, key) {
    var d = normalize(dock)
    if (d.shown && d.page === key) return changed(dock, {expanded: false})
    return changed(dock, {page: key, expanded: true})
}
/* The layout button flips what is seen: without room it reads as "below". */
function toggleSide(dock, roomForSide) {
    return changed(dock, {side: !(normalize(dock).side && roomForSide === true)})
}
function toggleShown(dock) { return changed(dock, {expanded: !normalize(dock).shown}) }

/* The divider was dragged to a pane of w × h: side by side keeps the width,
   below the list the height for this page. Hidden, there is nothing to keep
   and the same object comes back. */
function resized(dock, current, w, h) {
    if (!current.shown) return dock
    if (current.sideBySide) return changed(dock, {width: Math.round(w)})
    var values = {}
    values["height_" + current.page] = Math.round(h)
    return changed(dock, values)
}

/*
 * Where everything goes for a popup of env.width × env.height:
 *   env.gridUnit      Kirigami.Units.gridUnit
 *   env.headerHeight  the tab strip's height
 * pane holds the inspector's SplitView sizes; listMinW/listMinH the list's.
 */
function layout(dock, env) {
    var d = normalize(dock)
    var g = env.gridUnit
    var roomForSide = env.width >= g * 40
    // Beside the list when asked and there is room; a hidden inspector folds to
    // the strip below the list either way, so it never leaves an empty column.
    var sidePreferred = d.side && roomForSide
    var sideBySide = sidePreferred && d.shown
    // Preview is a glance; the other pages need room to work in.
    var defaultHeight = d.page === "preview" ? g * 12 : env.height * 0.55
    var wantedHeight = Number(setting(dock, "height_" + d.page, defaultHeight))
    var wantedWidth = Number(setting(dock, "width", g * 30))
    return {
        page: d.page,
        shown: d.shown,
        roomForSide: roomForSide,
        sidePreferred: sidePreferred,
        sideBySide: sideBySide,
        orientation: sideBySide ? "horizontal" : "vertical",
        pane: {
            minW: sideBySide ? g * 24 : 0,
            prefW: sideBySide ? Math.max(g * 24, wantedWidth) : -1,
            minH: sideBySide ? 0 : env.headerHeight,
            maxH: sideBySide || d.shown ? UNLIMITED : env.headerHeight,
            prefH: d.shown ? Math.max(g * 4, wantedHeight) : env.headerHeight
        },
        listMinW: sideBySide ? g * 14 : 0,
        listMinH: g * 6
    }
}
