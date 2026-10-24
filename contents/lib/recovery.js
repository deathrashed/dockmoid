.pragma library

/*
 * recovery.js — what to suggest when the engine cannot be reached.
 *
 * The same symptom ("nothing answers") has different fixes for a local Docker
 * daemon, rootless Docker, Podman and a remote host, and some fixes are not
 * Dockmoid's to offer (it can only start a local system Docker). Keys only;
 * the QML side words them.
 *
 *   ctx.problem            "missing" | "permission" | "down"
 *   ctx.podman             the engine is Podman
 *   ctx.remote             the endpoint is ssh:// or tcp://
 *   ctx.rootless           a per-user socket (/run/user/<uid>/…)
 *   ctx.canControlService  Dockmoid may run the configured start command
 *
 * Returns {cause, command, actions}: cause names the explanation, command is a
 * shell line worth copying ("" when none), actions lists buttons in order.
 */
function plan(ctx) {
    ctx = ctx || {};
    var actions = [];
    var cause, command = "";
    if (ctx.problem === "missing") {
        cause = ctx.podman ? "podman-missing" : "docker-missing";
        actions = ["install", "settings"];
    } else if (ctx.remote) {
        // Dockmoid cannot start or repair a remote daemon: point at the connection.
        cause = ctx.problem === "permission" ? "remote-denied" : "remote-down";
        actions = ["retry", "settings"];
    } else if (ctx.podman) {
        cause = ctx.problem === "permission" ? "podman-denied" : "podman-down";
        command = "systemctl --user start podman.socket";
        actions = ["copy", "retry", "settings"];
    } else if (ctx.rootless) {
        cause = ctx.problem === "permission" ? "rootless-denied" : "rootless-down";
        command = "systemctl --user start docker";
        actions = ["copy", "retry", "settings"];
    } else if (ctx.problem === "permission") {
        cause = "docker-denied";
        command = "sudo usermod -aG docker $USER";
        actions = ["copy", "retry", "settings"];
    } else {
        cause = "docker-down";
        actions = ctx.canControlService ? ["start", "retry", "settings"] : ["retry", "settings"];
    }
    return {cause: cause, command: command, actions: actions};
}
