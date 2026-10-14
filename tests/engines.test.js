const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
function loadLibrary(file) {
    const context = {};
    vm.createContext(context);
    vm.runInContext(fs.readFileSync(path.join(root, file), 'utf8'), context);
    return context;
}

const Engines = fs.existsSync(path.join(root, 'contents/lib/engines.js'))
    ? loadLibrary('contents/lib/engines.js') : {};
const Parsers = loadLibrary('contents/lib/parsers.js');

// Podman v5.7.1 CLI JSON is jsonOut(ListContainer) from:
// https://github.com/containers/podman/blob/v5.7.1/cmd/podman/containers/ps.go
// Its embedded ListContainer uses Id (not ID), Names[], CreatedAt, State, Status,
// Ports[] and Labels map. Port mappings use host_ip/host_port/container_port/protocol.
const podmanPsV571 = JSON.stringify([{
    Id: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    Image: 'docker.io/library/nginx:latest',
    Command: ['/docker-entrypoint.sh', 'nginx', '-g', 'daemon off;'],
    CreatedAt: '2 hours ago',
    Created: 1780000000,
    Names: ['/web'],
    State: 'running',
    Status: 'Up 2 hours (healthy)',
    Ports: [{host_ip: '127.0.0.1', host_port: 8080, container_port: 80, protocol: 'tcp'}],
    Labels: {'io.podman.compose.project': 'site'},
    Networks: ['podman'],
    Mounts: []
}]);

// Podman v5.0.3's versioned stats example uses these lower-case JSON keys:
// https://docs.podman.io/en/v5.0.3/markdown/podman-stats.1.html
// Rootless cgroups-v2 networking can be "-- / --"; that is unavailable data.
const podmanStatsV503 = JSON.stringify([{
    id: 'a9f807ffaacd', name: 'frosty_hodgkin', cpu_percent: '--',
    mem_usage: '3.092MB / 16.7GB', mem_percent: '0.02%',
    netio: '-- / --', blocki: '-- / --', pids: '2'
}]);

// Exact Podman v5.7.1 images --format json example fields:
// https://docs.podman.io/en/v5.7.1/markdown/podman-images.1.html#examples
const podmanImagesV571 = JSON.stringify([{
    id: 'e3d42bcaf643097dd1bb0385658ae8cbe100a80f773555c44690d22c25d16b27',
    names: ['docker.io/kubernetes/pause:latest'],
    digest: 'sha256:0aecf73ff86844324847883f2e916d3f6984c5fae3c2f23e91d66f549fe7d423',
    created: '2014-07-19T07:02:32.267701596Z',
    size: 250665
}]);

// Podman v5.7.1 documents these volume-list JSON properties, including
// MountCount as number of mounts (not container references):
// https://docs.podman.io/en/v5.7.1/markdown/podman-volume-ls.1.html
// Network fields and --no-trunc are documented here:
// https://docs.podman.io/en/v5.7.1/markdown/podman-network-ls.1.html
const podmanVolumesV571 = JSON.stringify([{
    Name: 'site_data', Driver: 'local', Scope: 'local', MountCount: 1,
    Labels: {'io.podman.compose.project': 'site'}
}]);
const podmanNetworksV571 = JSON.stringify([{
    ID: '0123456789abcdef0123456789abcdef', Name: 'podman', Driver: 'bridge',
    Labels: {}, IPv6Enabled: false, Internal: false, DNSEnabled: true
}]);

test('Podman command mapping changes only exact defaults', () => {
    const dockerEvents = "{engine} events --since {since} --until {until} --filter type=container --filter event=create --filter event=start --filter event=die --filter event=stop --filter event=kill --filter event=destroy --filter event=pause --filter event=unpause --filter event=restart --filter event=rename --filter event=update --filter event=oom --filter event=health_status --format '{{.Action}}'";
    const podmanEvents = "{engine} events --since {since} --until {until} --filter type=container --filter event=create --filter event=start --filter event=died --filter event=stop --filter event=kill --filter event=remove --filter event=pause --filter event=unpause --filter event=restart --filter event=rename --filter event=update --format '{{.Status}}'";
    assert.equal(Engines.template(dockerEvents, true), podmanEvents);
    assert.equal(Engines.template(dockerEvents + ' ', true), dockerEvents + ' ');
    assert.equal(Engines.template(dockerEvents, false), dockerEvents);
    assert.equal(Engines.template('{engine} system df -v --format json', true), '{engine} volume ls --format json');
    assert.equal(Engines.template('{engine} network ls --format json', true), '{engine} network ls --no-trunc --format json');
    assert.equal(Engines.template('{engine} system df -v --format json --human', true), '{engine} system df -v --format json --human');
});

test('Podman capability set is explicit and leaves unsupported features gated', () => {
    for (const feature of ['list', 'stats', 'events', 'logs', 'inspect', 'start', 'stop', 'restart', 'remove', 'pause', 'unpause', 'pull']) {
        assert.equal(Engines.supports(feature, true), true, feature);
    }
    for (const feature of ['compose', 'registryChecks', 'restartPolicies', 'systemDf', 'serviceControl', 'info']) {
        assert.equal(Engines.supports(feature, true), false, feature);
    }
    assert.equal(Engines.supports('contexts', true), true);
    assert.equal(Engines.supports('resources', true), true);
    assert.equal(Engines.supports('unknownFeature', true), false);
});

test('Podman v5.7.1 list JSON normalizes ID, name, health, labels and published ports', () => {
    const rows = Parsers.parseContainers(podmanPsV571);
    assert.equal(rows.length, 1);
    assert.equal(rows[0].id, '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef');
    assert.equal(rows[0].name, 'web');
    assert.equal(rows[0].state, 'running');
    assert.equal(rows[0].health, 'healthy');
    assert.equal(rows[0].createdAt, '2 hours ago');
    assert.equal(rows[0].ports, '127.0.0.1:8080->80/tcp');
    assert.equal(rows[0].networks, 'podman');
});

test('Podman v5.0.3 stats JSON reads documented fields and preserves unavailable values', () => {
    const stats = Parsers.parseStats(podmanStatsV503);
    assert.equal(stats.a9f807ffaacd.cpuPct, null);
    assert.equal(stats.a9f807ffaacd.memPct, 0.02);
    assert.equal(stats.a9f807ffaacd.memU, '3.092MB / 16.7GB');
    assert.equal(stats.a9f807ffaacd.netio, '-- / --');
    assert.equal(stats.a9f807ffaacd.blockio, '-- / --');
    assert.equal(stats.a9f807ffaacd.pids, '2');

    // A measured value can be parsed, while '--' remains unknown rather than 0.
    const measured = Parsers.parseStats(JSON.stringify([{
        id: 'stats-only', cpu_percent: '1.25%', mem_percent: '0.98%'
    }]));
    assert.equal(measured['stats-only'].cpuPct, 1.25);
    assert.equal(measured['stats-only'].memPct, 0.98);
});

test('Podman v5.7.1 resource JSON keeps unknown usage unknown', () => {
    const image = Parsers.parseImages(podmanImagesV571)[0];
    assert.equal(image.id, 'e3d42bcaf643097dd1bb0385658ae8cbe100a80f773555c44690d22c25d16b27');
    assert.equal(image.ref, 'docker.io/kubernetes/pause:latest');
    assert.equal(image.containers, -1);
    assert.equal(image.size, '250665');

    const volume = Parsers.parseVolumes(podmanVolumesV571)[0];
    assert.equal(volume.name, 'site_data');
    assert.equal(volume.links, -1);
    assert.equal(volume.size, '');

    const network = Parsers.parseNetworks(podmanNetworksV571)[0];
    assert.equal(network.id, '0123456789abcdef0123456789abcdef');
    assert.equal(network.name, 'podman');
    assert.equal(network.builtin, true);
});
