.pragma library

/*
 * pages.js — the places Go to can open, in the order it lists them.
 *
 *   key    what PopupView.goToPage is asked for
 *   glyph  the lucide icon shown beside it
 *   label  English, for tests and as a fallback; the QML side words it with
 *          i18n (SearchControl.pageLabels) so the strings stay extractable
 *   kind   how it opens:
 *            home       the container list itself (back to the first page)
 *            stack      a page pushed over the list
 *            inspector  a tab of the inspector below the list
 *            settings   the widget's settings dialog
 */
var PAGES = [
    {key: "containers", glyph: "boxes", label: "Containers", kind: "home"},
    {key: "deploy", glyph: "package-plus", label: "Deploy", kind: "stack"},
    {key: "resources", glyph: "drive-harddisk", label: "Resources", kind: "stack"},
    {key: "health", glyph: "heart-pulse", label: "Health", kind: "inspector"},
    {key: "doctor", glyph: "stethoscope", label: "Doctor", kind: "stack"},
    {key: "activity", glyph: "bell-ring", label: "Activity", kind: "stack"},
    {key: "problem", glyph: "bug", label: "Problem Report", kind: "stack"},
    {key: "settings", glyph: "configure", label: "Settings", kind: "settings"}
]

/* Copies, so a caller cannot change the registry. */
function list() {
    return PAGES.map(function (page) { return {key: page.key, glyph: page.glyph, label: page.label, kind: page.kind} })
}
/* The page for key, or null. */
function find(key) {
    for (var i = 0; i < PAGES.length; i++) if (PAGES[i].key === key) return list()[i]
    return null
}
