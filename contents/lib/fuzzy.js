.pragma library

/*
 * fuzzy.js — forgiving matching for navigation ("dpl" finds "deploy").
 *
 * The query's letters must appear in the text in order, not necessarily next
 * to each other. A score ranks the matches: letters that start a word or
 * follow each other count more, and gaps count less. No match gives -1.
 * Case and separators (space, - _ . / :) are ignored when matching.
 */
function isBoundary(ch) { return ch === " " || ch === "-" || ch === "_" || ch === "." || ch === "/" || ch === ":" }

function score(query, text) {
    var q = String(query || "").toLowerCase().replace(/[\s\-_.\/:]+/g, "")
    var t = String(text || "").toLowerCase()
    if (q === "") return 0
    var total = 0, at = -1, previous = -2, start = -1
    for (var i = 0; i < q.length; i++) {
        var found = -1
        for (var j = at + 1; j < t.length; j++) {
            if (t.charAt(j) === q.charAt(i)) { found = j; break }
        }
        if (found < 0) return -1
        var points = 1
        if (found === 0 || isBoundary(t.charAt(found - 1))) points += 3
        if (found === previous + 1) points += 2
        total += points - Math.min(3, Math.max(0, found - at - 1)) * 0.1
        if (start < 0) start = found
        previous = found
        at = found
    }
    // Earlier matches and shorter names rank higher.
    return total - start * 0.05 - t.length * 0.01
}

/* Keep the items whose text matches, best first. `textOf` reads each item's text. */
function rank(query, items, textOf) {
    var scored = []
    for (var i = 0; i < items.length; i++) {
        var s = score(query, textOf(items[i]))
        if (s >= 0) scored.push({item: items[i], score: s})
    }
    scored.sort(function (a, b) { return b.score - a.score })
    return scored.map(function (x) { return x.item })
}
