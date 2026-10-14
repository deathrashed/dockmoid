.pragma library

/*
 * Opacity tokens for the popup's chrome.
 *
 * Call sites still pick the Kirigami colour, so a theme change keeps working:
 *
 *     color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface1)
 *
 * Names describe the role, not the number. Keep this file pure so the values
 * can be tested without a Qt runtime.
 */
var ALPHA = {
    /* Fills laid over the window background. */
    surface1: 0.03,       // bands, section panels, status bar, row stripes
    surface2: 0.045,      // cards, tiles, preview pane, collapsed headers
    surface3: 0.06,       // table header
    hover: 0.09,          // neutral hover on a surface
    /* Accent and semantic washes. */
    tintWeak: 0.08,       // faint wash: selected plan, update chips, sparkline
    tintStrong: 0.15,     // accent fill while hovered or selected
    tintHover: 0.25,      // accent fill on an already-tinted header
    /* Lines. */
    divider: 0.08,        // hairline between rows
    borderFaint: 0.12,    // card outlines
    border: 0.2,          // separators, split handles, emphasised outlines
    borderSoft: 0.3,      // outline of a ghost badge
    borderAccent: 0.45,   // outline of a tinted chip
    borderStrong: 0.7,    // outline of a selected or hovered tinted item
    /* Gauges. */
    track: 0.12           // empty part of a usage bar
};

/*
 * Accent hues beyond the theme's semantic colours. Mid-tones, so they stay
 * readable on both light and dark panels. Use them to tell things apart (CPU
 * vs memory, updates vs health), never to say "good" or "bad": that stays with
 * the theme's positive, neutral and negative colours.
 */
var HUE = {
    cyan: "#15aabf",
    blue: "#339af0",
    violet: "#845ef7",
    pink: "#e64980",
    amber: "#f59f00",
    teal: "#12b886",
    slate: "#868e96"
};

/* Every value must be a usable opacity. Used by the tests. */
function isValid(value) {
    return typeof value === "number" && value > 0 && value <= 1;
}

/* Ordered fills, quietest first, for tests and for choosing between levels. */
var SURFACES = ["surface1", "surface2", "surface3", "hover"];
