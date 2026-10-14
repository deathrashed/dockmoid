import QtQuick
import "../../lib/iconCatalog.js" as Catalog

/* Load lightweight upstream indexes only when the chooser is opened.
 * Search stays in memory; images are fetched only for visible results. */
QtObject {
    id: catalog
    property var entries: []
    property var data: ({})
    property var requests: ({})
    property var failures: ({})
    property bool started: false
    property bool busy: false
    property string error: ""
    property Timer deadline: Timer {
        interval: 35000
        onTriggered: {
            var active = Object.keys(catalog.requests)
            for (let i = 0; i < active.length; i++) {
                let provider = active[i]
                let request = catalog.requests[provider]
                delete catalog.requests[provider]
                request.abort()
                catalog.failures[provider] = i18n("%1: request timed out", Catalog.providers[provider].name)
            }
            catalog.updateState()
        }
    }

    function updateState() {
        entries = (data.dashboard || []).concat(data.selfhst || [])
        error = Object.keys(failures).map(function(p) { return catalog.failures[p] }).join("\n")
        busy = Object.keys(requests).length > 0
        if (!busy) deadline.stop()
    }

    function load(force) {
        if (busy || (started && !force)) return
        started = true
        failures = ({})
        var sources = ["dashboard", "selfhst"]
        for (let i = 0; i < sources.length; i++) {
            let provider = sources[i]
            let request = new XMLHttpRequest()
            requests[provider] = request
            request.onreadystatechange = function() {
                if (request.readyState !== XMLHttpRequest.DONE || catalog.requests[provider] !== request) return
                delete catalog.requests[provider]
                try {
                    if (request.status !== 200) throw new Error(i18n("network error (HTTP %1)", request.status))
                    let response = JSON.parse(request.responseText)
                    catalog.data[provider] = provider === "dashboard" ? Catalog.fromDashboard(response) : Catalog.fromSelfhst(response)
                } catch (e) {
                    catalog.failures[provider] = Catalog.providers[provider].name + ": " + String(e.message || e)
                }
                catalog.updateState()
            }
            request.open("GET", Catalog.providers[provider].index)
            request.send()
        }
        updateState()
        deadline.start()
    }

    Component.onDestruction: {
        var pending = requests
        requests = ({})
        var active = Object.keys(pending)
        for (let i = 0; i < active.length; i++) pending[active[i]].abort()
    }
}
