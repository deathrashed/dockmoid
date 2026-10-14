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

/* Tone of the glyph in front of the status text. */
function glyphTone(attention, isRunning) {
    if (attention === "failed" || attention === "unhealthy") return "bad"
    if (attention === "paused" || attention === "restarting") return "warn"
    return isRunning ? "ok" : "muted"
}

/* Glyph name for a status line. mode: "always", "attention" or "none". */
function statusGlyph(attention, busy, isRunning, mode) {
    if (mode === "none") return ""
    var byAttention = {failed: "circle-x", unhealthy: "dialog-warning", paused: "media-playback-pause", restarting: "view-refresh"}
    if (mode === "attention") return byAttention[attention] || ""
    if (busy) return "view-refresh"
    return byAttention[attention] || (isRunning ? "container-running" : "container-exited")
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
