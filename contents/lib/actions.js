.pragma library

/*
 * actions.js — which container actions are possible right now.
 *
 * Every view (menu, list row, grid card, table row, detail header, inspector)
 * asks here instead of repeating the rules, so a button and the handler it
 * calls can never disagree. Pure functions of a record and a context:
 *
 *   ctx.readOnly     monitoring mode: nothing that changes a container
 *   ctx.busy         an action on this container is already running
 *   ctx.engineActive the engine answers (default true)
 *   ctx.compose      the record is a Compose service this host can drive
 *
 * States are Docker's, plus "not-created" for a Compose service that has no
 * container yet. A paused container is not "running" (isRunning is false), so
 * rules look at the state, never at isRunning.
 */

function stateOf(rec) {
    return String(rec ? (rec.containerState !== undefined ? rec.containerState : rec.state) || "" : "");
}

function allowed(rec, ctx) {
    ctx = ctx || {};
    var s = stateOf(rec);
    var known = !!rec && !!rec.id;
    var exists = known && s !== "not-created";
    var write = known && !ctx.readOnly && !ctx.busy && ctx.engineActive !== false;
    var running = s === "running";
    var paused = s === "paused";
    var looping = s === "restarting";
    return {
        details: known,
        logs: exists,
        inspect: exists,
        create: write && s === "not-created",
        start: write && (s === "exited" || s === "created" || s === "dead"),
        // A crash-looping container is exactly the one you want to stop.
        stop: write && (running || paused || looping),
        // Restarting a paused container is refused by the engine; Resume is the action.
        restart: write && (running || looping || s === "exited"),
        pause: write && running,
        resume: write && paused,
        kill: write && (running || paused || looping),
        forceRestart: write && (running || looping),
        recreate: write && exists && ctx.compose === true,
        update: write && exists,
        remove: write && exists,
        rename: write && exists,
        exec: known && !ctx.readOnly && ctx.engineActive !== false && running
    };
}

/*
 * The one start/stop button a compact view shows: Stop while it runs (or is
 * paused or looping), Create for an undeployed service, otherwise Start.
 * enabled says whether pressing it would do anything now.
 */
function primary(rec, ctx) {
    var can = allowed(rec, ctx);
    var s = stateOf(rec);
    var action = s === "running" || s === "paused" || s === "restarting" ? "stop"
        : s === "not-created" ? "create" : "start";
    return { action: action, enabled: can[action] === true };
}
