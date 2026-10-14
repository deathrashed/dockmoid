/* Bundle action artwork so every menu/button works independently of the icon theme.
 * Paths are resolved by components one directory below contents/ui. */
function path(name) {
    if (name === "docker") return "../../assets/logo-docker.svg";
    var names = {
        "document-view": "info", "document-properties": "file-braces",
        "copy-name": "tag", "copy-id": "hash", "copy-image": "file-image",
        "copy-project": "folder-kanban", "copy-service": "workflow", "copy-compose": "file-code",
        "text-x-generic": "file-text", "text-x-log": "terminal",
        "utilities-system-monitor": "activity", "utilities-terminal": "terminal",
        "configure": "sliders-horizontal", "preferences-desktop-icons": "palette",
        "image": "image-plus", "insert-link": "link", "internet-web-browser": "external-link",
        "document-open": "folder-open", "folder": "folder", "edit-copy": "copy",
        "window-pin": "pin", "window-unpin": "pin-off", "edit-delete": "trash",
        "edit-rename": "pencil", "document-edit": "pencil", "edit-undo": "undo-2",
        "go-up": "arrow-up", "go-down": "arrow-down", "go-previous": "arrow-left",
        "media-playback-start": "play", "media-playback-stop": "square",
        "media-playback-pause": "pause", "process-stop": "octagon-x",
        "startup-manual": "square", "startup-failure": "circle-alert",
        "startup-unless-stopped": "circle-pause", "startup-always": "repeat",
        "view-refresh": "rotate-cw", "media-playlist-repeat": "refresh-cw",
        "package-upgrade": "cloud-download", "system-download": "download",
        "dialog-warning": "circle-alert", "application-menu": "ellipsis-vertical",
        "checkmark": "check", "edit-find": "search", "document-save": "save",
        "drive-harddisk": "hard-drive", "edit-clear-history": "brush-cleaning",
        "network-server": "server", "view-sort-ascending": "arrow-down-wide-narrow",
        "view-list-text": "list", "view-list-details": "table", "view-list-tree": "network",
        "view-grid": "layout-grid", "view-visible": "eye", "window-new": "external-link",
        "edit-clear": "x", "package-check": "package-check", "package-search": "package-search",
        "window-maximize": "maximize", "window-restore": "copy", "chevron-down": "chevron-down",
        "container-running": "arrow-up", "container-exited": "log-out",
        "view-filter": "list-filter", "list-add": "package-plus", "bell": "bell",
        "package": "package", "cpu": "cpu", "memory": "memory-stick", "circle-x": "circle-x", "bookmark": "bookmark", "system-shutdown": "power", "go-next": "chevron-right", "go-previous-arrow": "chevron-left"
    };
    var key = String(name).replace(/-symbolic$/, "");
    /* A name that is not a mapped theme name is taken to be a lucide icon name. */
    return "../../assets/lucide/" + (names[key] || (/^[a-z0-9]+(-[a-z0-9]+)*$/.test(key) ? key : "external-link")) + ".svg";
}
