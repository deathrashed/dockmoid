.pragma library

// Docker status strings are retained verbatim for the tooltip. This short
// label keeps only the elapsed time (for example, "Up 4 hours" -> "4h").
function compactDuration(value) {
    var text = String(value || "").trim().replace(/\s+ago$/i, "")
    if (/^Less than a second$/i.test(text)) return "<1s"
    var duration = text.match(/^(?:About\s+)?(a|an|[0-9]+)\s+(seconds?|minutes?|hours?|days?|weeks?|months?|years?)$/i)
    if (!duration) return ""
    var amount = duration[1].toLowerCase() === "a" || duration[1].toLowerCase() === "an" ? "1" : duration[1]
    var unit = duration[2].toLowerCase()
    var suffix = unit.indexOf("second") === 0 ? "s"
        : unit.indexOf("minute") === 0 ? "m"
        : unit.indexOf("hour") === 0 ? "h"
        : unit.indexOf("day") === 0 ? "d"
        : unit.indexOf("week") === 0 ? "w"
        : unit.indexOf("month") === 0 ? "mo" : "y"
    return amount + suffix
}

function compactStatus(status, state, runningFor) {
    var value = String(status || "").trim()
    var match = value.match(/(?:Up|Exited(?:\s*\([^)]*\))?|Restarting(?:\s*\([^)]*\))?)\s+((?:Less than a second)|(?:(?:About\s+)?(?:a|an|[0-9]+)\s+(?:seconds?|minutes?|hours?|days?|weeks?|months?|years?)))/i)
    var shortDuration = match ? compactDuration(match[1]) : ""
    if (!shortDuration && !value) shortDuration = compactDuration(runningFor)
    return shortDuration || value || String(state || "")
}

function attentionKind(record) {
    var state = String(record.containerState || record.state || "").toLowerCase()
    if ((state === "running" || record.isRunning) && (record.health === "unhealthy" || record.probe === "down")) return "unhealthy"
    if (state === "not-created") return "not-created"
    if (state === "restarting") return "restarting"
    if (state === "paused") return "paused"
    if (state === "dead") return "failed"
    var match = /^Exited\s*\((\d+)\)/i.exec(String(record.status || ""))
    if (state === "exited" && match && [0,130,137,143].indexOf(Number(match[1])) < 0) return "failed"
    return state === "running" || record.isRunning ? "running" : "stopped"
}

/* ---- Presentation helpers shared by every view that draws a status line. ----
   They return keys, never translated text, so the QML side owns i18n. */

/* Tone of the status text: "ok" | "bad" | "warn" | "text" | "muted". */
function statusTone(attention, operationLabel, operationOk, isRunning) {
    if (operationLabel) return operationOk ? "ok" : "bad"
    if (attention === "failed" || attention === "unhealthy") return "bad"
    if (attention === "paused" || attention === "restarting") return "warn"
    return isRunning ? "text" : "muted"
}

/* Problem states are the ones worth a badge in a list. */
function isProblem(attention) {
    return ["failed", "unhealthy", "paused", "restarting"].indexOf(attention) >= 0
}

/* Tone of the glyph in front of the status text. */
function glyphTone(attention, isRunning) {
    if (attention === "failed" || attention === "unhealthy") return "bad"
    if (attention === "paused" || attention === "restarting") return "warn"
    if (attention === "not-created") return "blue"
    return isRunning ? "ok" : "rose"
}

/* Glyph name for a status line. mode: "always", "attention" or "none". */
function statusGlyph(attention, busy, isRunning, mode) {
    if (mode === "none") return ""
    var byAttention = {failed: "circle-x", unhealthy: "dialog-warning", paused: "media-playback-pause", restarting: "view-refresh"}
    if (mode === "attention") return byAttention[attention] || ""
    if (busy) return "view-refresh"
    if (attention === "not-created") return "circle-plus"
    return byAttention[attention] || (isRunning ? "circle-play" : "circle-stop")
}

/* Key of the word shown before the status, or "" when there is none. */
function prefixKey(attention) {
    return ["failed", "unhealthy", "paused", "restarting"].indexOf(attention) >= 0 ? attention : ""
}

/* Tone of the stripe on a card: "" when the container is simply stopped. */
function accentTone(attention) {
    if (attention === "stopped" || attention === "not-created" || attention === "") return ""
    return glyphTone(attention, attention === "running")
}

/* How a state badge looks. Returns keys only: the QML side owns the words.
   variant: "ghost" | "outline"; dot: draw a status dot. */
function badgeSpec(attention) {
    switch (attention) {
    case "running": return {key: "running", tone: "ok", variant: "ghost", glyph: "", dot: true}
    case "unhealthy": return {key: "unhealthy", tone: "bad", variant: "ghost", glyph: "heart-pulse", dot: false}
    case "failed": return {key: "failed", tone: "bad", variant: "ghost", glyph: "circle-x", dot: false}
    case "paused": return {key: "paused", tone: "amber", variant: "ghost", glyph: "pause", dot: false}
    case "restarting": return {key: "restarting", tone: "amber", variant: "ghost", glyph: "rotate-cw", dot: false}
    case "not-created": return {key: "not-created", tone: "blue", variant: "outline", glyph: "circle-plus", dot: false}
    default: return {key: "stopped", tone: "rose", variant: "outline", glyph: "", dot: false}
    }
}

/* ---- Timeline: when a container started, stopped or was created. ----
   Times come from inspect (startedAtMs, finishedAtMs, createdMs, epoch ms).
   Returns entries {kind, at, span}: kind "up" (started, still running),
   "down" (stopped), "created" (created, never started or recreated recently).
   `span` is a compact age ("7h 24m", "9d"); the QML side adds icons, dates
   and words in tooltips. Empty when the engine gave no times. */

function span(ms) {
    var s = Math.max(0, Math.floor(ms / 1000))
    if (s < 60) return s + "s"
    var m = Math.floor(s / 60)
    if (m < 60) return m + "m"
    var h = Math.floor(m / 60)
    if (h < 24) return h + "h" + (m % 60 ? " " + (m % 60) + "m" : "")
    var d = Math.floor(h / 24)
    if (d < 7) return d + "d" + (h % 24 ? " " + (h % 24) + "h" : "")
    if (d < 60) return d + "d"
    if (d < 730) return Math.floor(d / 30) + "mo"
    return Math.floor(d / 365) + "y"
}

function timeline(rec, now) {
    if (!rec) return []
    var state = String(rec.containerState || rec.state || "")
    var started = Number(rec.startedAtMs || 0), finished = Number(rec.finishedAtMs || 0), created = Number(rec.createdMs || 0)
    var out = []
    if ((state === "running" || state === "paused" || state === "restarting") && started > 0)
        out.push({kind: "up", at: started, span: span(now - started)})
    else if ((state === "exited" || state === "dead") && finished > 0)
        out.push({kind: "down", at: finished, span: span(now - finished)})
    // Created on its own when never started; beside the uptime when the
    // container was (re)created in the last month and restarted since.
    if (state === "not-created" || created <= 0) return out
    if (state === "created" || (started === 0 && out.length === 0))
        out.push({kind: "created", at: created, span: span(now - created)})
    else if (out.length > 0 && out[0].kind === "up" && now - created < 30 * 86400000 && started - created > 60000)
        out.push({kind: "created", at: created, span: span(now - created)})
    return out
}

/* What an exit code usually means, as a key (QML words it). A convention, not
   proof: applications may use any code. */
function exitMeaning(code, oom) {
    if (oom) return "oom"
    code = Number(code)
    if (isNaN(code) || code < 0) return ""
    if (code === 0) return "clean"
    if (code === 137) return "killed"
    if (code === 143) return "terminated"
    if (code === 130) return "interrupted"
    if (code === 125) return "engine"
    if (code === 126) return "not-executable"
    if (code === 127) return "not-found"
    if (code === 139) return "segfault"
    return code > 128 ? "signal" : "app"
}

/*
 * A container's health, as a key the QML side words (DockerBackend
 * healthWords). `facts` is the inspect read (Parsers.parseFacts) or null;
 * `factsRead` says whether that read has answered. Returns
 * {key, tone, streak, status}:
 *   key "none" (no container), "not-created", "reading" (inspect pending),
 *   "unknown" (inspect answered with nothing), "no-check" (no healthcheck
 *   configured), "no-result" (configured, no result yet), "healthy",
 *   "starting", "unhealthy", or "other" (an engine status word, in `status`).
 * Until inspect answers, the list's own health word stands in.
 */
function healthTone(status) {
    return status === "healthy" ? "ok" : status === "unhealthy" ? "bad" : status === "starting" ? "warn" : "muted"
}
function healthState(facts, record, factsRead) {
    var h = facts ? facts.health : null
    var status = h ? String(h.status || "") : String(record && record.health || "")
    var state = {key: "", tone: healthTone(status), streak: h ? Number(h.failingStreak) || 0 : 0, status: status}
    if (!record) state.key = "none"
    else if (record.state === "not-created") state.key = "not-created"
    else if (!facts) state.key = status !== "" && status !== "none" ? "other" : factsRead ? "unknown" : "reading"
    else if (!h) state.key = facts.healthCheck === "" ? "no-check" : "no-result"
    else state.key = ["healthy", "starting", "unhealthy"].indexOf(status) >= 0 ? status : "other"
    return state
}

/* Lines worth reading first in a log tail: errors, warnings, panics. At most `limit`, newest last. */
function problemLines(text, limit) {
    var lines = String(text || "").split("\n")
    var out = []
    for (var i = 0; i < lines.length; i++) {
        if (/\b(error|err|fatal|panic|exception|fail(ed|ure)?|warn(ing)?|denied|refused|traceback|oom|killed)\b/i.test(lines[i])) out.push(lines[i])
    }
    return out.slice(-Math.max(1, limit || 20))
}

/*
 * Log digest: what keeps going wrong in a tail of log lines, without reading
 * every line. Lines are normalised (timestamps, numbers, hex ids, quoted
 * values) so "request 41 took 80ms" and "request 42 took 9ms" count as one
 * message. Returns {lines, errors, warnings, items}, where each item is
 * {kind, level, count, sample, first, last}:
 *   kind "loop"      the same message again and again in a row (a crash loop, a retry storm)
 *   kind "recurring" the same message many times across the tail
 *   kind "single"    an error or warning seen once or twice
 * Ordered most important first. Counts describe the tail only.
 */
function logLevel(line) {
    if (/\b(fatal|panic|critical|crit)\b/i.test(line)) return "error"
    if (/\b(error|err|exception|traceback|failed|failure|denied|refused|killed|segfault)\b/i.test(line)) return "error"
    if (/\b(warn|warning)\b/i.test(line)) return "warning"
    return ""
}
function normaliseLine(line) {
    return String(line)
        .replace(/\u001b\[[0-9;]*[A-Za-z]/g, "")
        .replace(/^\S*\d{4}-\d\d-\d\dT[0-9:.]+Z?\s*/, "")
        .replace(/\b\d{4}[-/]\d\d[-/]\d\d[ T][0-9:.,+\-Z]+/g, "")
        .replace(/\b[0-9a-f]{12,64}\b/gi, "<id>")
        .replace(/\b\d+(\.\d+)?(ms|s|us|ns|kB|MB|GB|%)?\b/g, "<n>")
        .replace(/"[^"]*"/g, "\"…\"")
        .replace(/\s+/g, " ")
        .trim()
}
function digestLogs(text) {
    var lines = String(text || "").split("\n").filter(function (l) { return l.trim() !== "" })
    var groups = {}, order = [], errors = 0, warnings = 0
    lines.forEach(function (raw, index) {
        var level = logLevel(raw)
        if (level === "error") errors++
        else if (level === "warning") warnings++
        if (level === "") return
        var key = normaliseLine(raw)
        if (!groups[key]) { groups[key] = {key: key, level: level, count: 0, sample: raw.replace(/\u001b\[[0-9;]*[A-Za-z]/g, "").replace(/^\S*\d{4}-\d\d-\d\dT[0-9:.]+Z?\s*/, "").trim(), firstIndex: index, lastIndex: index, run: 0, bestRun: 0, runEnd: -1}; order.push(key) }
        var g = groups[key]
        if (level === "error") g.level = "error"
        g.count++
        g.lastIndex = index
        g.run = g.runEnd === index - 1 ? g.run + 1 : 1
        g.runEnd = index
        if (g.run > g.bestRun) g.bestRun = g.run
    })
    var items = order.map(function (key) {
        var g = groups[key]
        var kind = g.bestRun >= 3 ? "loop" : g.count >= 5 ? "recurring" : "single"
        return {kind: kind, level: g.level, count: g.count, run: g.bestRun, sample: g.sample, first: g.firstIndex, last: g.lastIndex}
    })
    var rank = {loop: 0, recurring: 1, single: 2}
    items.sort(function (a, b) {
        return rank[a.kind] - rank[b.kind] || (a.level === "error" ? 0 : 1) - (b.level === "error" ? 0 : 1) || b.count - a.count
    })
    return {lines: lines.length, errors: errors, warnings: warnings, items: items.slice(0, 12)}
}
