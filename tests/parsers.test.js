// node tests/parsers.test.js
const vm = require("vm"), fs = require("fs"), path = require("path"), assert = require("assert");
const ctx = {}; vm.createContext(ctx);
vm.runInContext(fs.readFileSync(path.join(__dirname, "../contents/lib/parsers.js"), "utf8"), ctx);
const P = ctx;
const json = (v) => JSON.stringify(v);

// docker (NDJSON) and podman (array) both parse
const dockerOut = json({ID:"aaaaaaaaaaaa1111",Names:"web",Image:"nginx",State:"running",Status:"Up 2 hours (unhealthy)",HealthStatus:"unhealthy",Ports:"0.0.0.0:8080->80/tcp, 0.0.0.0:53->53/udp",Labels:"com.docker.compose.project=site,a=b"}) + "\n" + "garbage\n";
let c = P.parseContainers(dockerOut);
assert.strictEqual(c.length, 1); assert.strictEqual(c[0].project, "site");
const podmanOut = json([{Id:"bbbbbbbbbbbb2222",Names:["db"],Image:"pg",State:"exited",Status:"Exited (1) 3 minutes ago",Ports:[{host_ip:"",host_port:5432,container_port:5432,protocol:"tcp"}],Labels:{"com.docker.compose.project":"x"}}]);
c = P.parseContainers(podmanOut);
assert.strictEqual(c[0].name, "db"); assert.ok(/5432->5432\/tcp/.test(c[0].ports)); assert.strictEqual(c[0].project, "x");

// links: tcp only, deduplicated
const links = P.buildLinks("0.0.0.0:22000->22000/tcp, 0.0.0.0:22000->22000/udp, [::]:22000->22000/tcp", {lanHost:"10.0.0.2"});
assert.strictEqual(links.length, 1); assert.strictEqual(links[0].host, "10.0.0.2");

// stopped containers never count as unhealthy
const agg = P.aggregate([{isRunning:false,health:"unhealthy",state:"exited",cpuPct:0,memPct:0,pids:""},{isRunning:true,health:"unhealthy",state:"running",cpuPct:1,memPct:1,pids:"3"}]);
assert.strictEqual(agg.unhealthy, 1);

// state diff
const mk = (state, health, status) => ({ name:"n", state, health, exitCode: P.exitCodeFromStatus(status || "") });
let ev = P.diffStates(null, {a: mk("running","none")}); assert.strictEqual(ev.length, 0);
ev = P.diffStates({a: mk("running","none")}, {a: mk("exited","none","Exited (1) 2 seconds ago")}); assert.strictEqual(ev[0].kind, "crashed");
ev = P.diffStates({a: mk("running","none")}, {a: mk("exited","none","Exited (143) 2 seconds ago")}); assert.strictEqual(ev[0].kind, "stopped");
ev = P.diffStates({a: mk("running","healthy")}, {a: mk("running","unhealthy")}); assert.strictEqual(ev[0].kind, "unhealthy");
ev = P.diffStates({a: mk("running","unhealthy")}, {a: mk("running","healthy")}); assert.strictEqual(ev[0].kind, "recovered");
ev = P.diffStates({a: mk("running","none")}, {a: mk("restarting","none")}); assert.strictEqual(ev[0].kind, "restarting");
ev = P.diffStates({}, {a: mk("running","none")}); assert.strictEqual(ev.length, 0);

// restart policies
const pol = P.parseRestartPolicies("abcdefabcdef1234 unless-stopped 0\n123456789012ffff  0\n");
assert.strictEqual(pol.abcdefabcdef, "unless-stopped"); assert.strictEqual(pol["123456789012"], "no");
// container times from the same inspect line; policy-only lines carry none
const times = P.parseLifeTimes("abcdefabcdef1234 unless-stopped 0 2026-10-24T04:36:00.123456789Z 0001-01-01T00:00:00Z 2026-10-23T05:00:00Z\n123456789012ffff  0 2026-10-01T00:00:00Z 2026-10-15T08:00:00.5Z 2026-09-30T00:00:00Z\nfedcba987654 no 0\n");
assert.strictEqual(times.abcdefabcdef.startedAt, Date.UTC(2026, 9, 24, 4, 36, 0, 123)); assert.strictEqual(times.abcdefabcdef.finishedAt, 0);
assert.strictEqual(times["123456789012"].finishedAt, Date.UTC(2026, 9, 15, 8, 0, 0, 500)); assert.strictEqual(times.fedcba987654, undefined);

// launchers
const l = P.parseLaunchers("# c\nKonsole|konsole|container|konsole -e docker exec -it {id} {shell}\nbad|line\nCode|code|project|code {dir}");
assert.strictEqual(l.length, 2); assert.strictEqual(l[1].binary, "code");

// literal search escaping
assert.ok(new RegExp(P.escapeRegExp("a(b"), "i").test("xa(bz"));
assert.ok(P.isSafeToken("my-proj_1")); assert.ok(!P.isSafeToken("a;rm"));
console.log("parsers ok");

// ---- resources, updates, alerts, probes, compose
const imgs = P.parseImages(json({ID:"abc",Repository:"nginx",Tag:"latest",Size:"1MB",Containers:"2"}) + "\n" + json({ID:"d",Repository:"<none>",Tag:"<none>",Containers:"0"}));
assert.strictEqual(imgs[0].ref, "nginx:latest"); assert.ok(imgs[1].dangling && imgs[1].containers === 0);
const vols = P.parseVolumes(json({Images:[],Volumes:[{Name:"v1",Driver:"local",Size:"266B",Links:"0",Labels:"com.docker.compose.project=p"},{Name:"v2",Size:"N/A",Links:"2"}]}));
assert.strictEqual(vols[0].links, 0); assert.strictEqual(vols[0].project, "p"); assert.strictEqual(vols[1].size, "");
const d1 = "sha256:" + "a".repeat(64), d2 = "sha256:" + "b".repeat(64);
assert.strictEqual(P.compareDigests("repo@" + d1 + "|" + d1), "current");
assert.strictEqual(P.compareDigests("repo@" + d1 + "|" + d2), "update");
assert.strictEqual(P.compareDigests("|" + d1), "unknown"); assert.strictEqual(P.compareDigests("repo@" + d1 + "|"), "unknown");
assert.ok(!P.isCheckableImage("0c994536bddb")); assert.ok(P.isCheckableImage("nginx:1"));
const st = {}; const hot = [{id:"a",name:"a",isRunning:true,cpuPct:95,memPct:1}];
assert.strictEqual(P.trackThresholds(st, hot, 0, {cpu:90,mem:0,seconds:60}).length, 0);
assert.strictEqual(P.trackThresholds(st, hot, 30000, {cpu:90,mem:0,seconds:60}).length, 0);
assert.strictEqual(P.trackThresholds(st, hot, 61000, {cpu:90,mem:0,seconds:60}).length, 1);
assert.strictEqual(P.trackThresholds(st, hot, 90000, {cpu:90,mem:0,seconds:60}).length, 0);   // once per episode
const rules = P.parseProbeRules("web=http://localhost:8080/health\nbad=ftp://x\n$(x)=http://a");
assert.strictEqual(rules.length, 2); assert.strictEqual(P.probeUrlFor({name:"Web",probeUrl:""}, rules), "http://localhost:8080/health");
assert.strictEqual(P.probeUrlFor({name:"x",probeUrl:"http://a/b'rm"}, []), "");
assert.strictEqual(P.parseProbeResults("http://a 200 12\nhttp://b 000 0")["http://b"].up, false);
assert.strictEqual(P.composeFileArgs("/a/x.yml,/a/y.yml", (s) => "'" + s + "'"), "-f '/a/x.yml' -f '/a/y.yml'");
assert.deepStrictEqual(P.pushSample([1,2,3], 4, 3), [2,3,4]);
console.log("parsers (extended) ok");

{
 const id='abcdef123456'+'0'.repeat(52);
 const rows=[{id,isRunning:true}];
 const stats=P.parseStats(JSON.stringify({ID:'abcdef123456',CPUPerc:'0.12%',MemPerc:'0.3%'}));
 P.applyStats(rows,stats);
 assert.equal(rows[0].cpu,'0.12%','full inventory IDs still join short stats IDs');
}

// Detail-page facts: zero Go times are "unknown", NONE health checks are hidden,
// shell-form checks drop their CMD-SHELL marker and limits convert from bytes/nanoCPUs.
{
 const f=P.parseFacts(JSON.stringify({restarts:3,started:'2026-10-24T01:00:00Z',finished:'0001-01-01T00:00:00Z',exitCode:137,error:'',oom:true,memory:536870912,nanoCpus:1500000000,
   networks:{web:{IPAddress:'172.18.0.5'},none:{IPAddress:''}},healthcheck:{Test:['CMD-SHELL','curl -f localhost'],Interval:30000000000},user:'1000',workdir:'/app'}));
 assert.equal(f.restarts,3);assert.equal(f.finishedAt,0);assert.ok(f.startedAt>0);assert.equal(f.oomKilled,true);
 assert.equal(f.memoryLimit,536870912);assert.equal(f.cpuLimit,1.5);
 assert.deepEqual(JSON.parse(JSON.stringify(f.networks)),[{name:'web',ip:'172.18.0.5',ipv6:''}]);
 assert.equal(f.healthCheck,'curl -f localhost');assert.equal(f.healthInterval,30);
 assert.equal(P.parseFacts(JSON.stringify({healthcheck:{Test:['NONE']}})).healthCheck,'');
 assert.equal(P.parseFacts(JSON.stringify({healthcheck:null})).healthCheck,'');
}

// health record from inspect facts: status, streak and the last probe; null without a healthcheck
{
  const f = P.parseFacts(JSON.stringify({restarts: 0, health: {Status: "unhealthy", FailingStreak: 3, Log: [{ExitCode: 0, End: "2026-10-24T10:00:00Z", Output: "ok"}, {ExitCode: 1, End: "2026-10-24T10:00:30Z", Output: "curl: (7) refused\n"}]}}));
  assert.strictEqual(f.health.status, "unhealthy"); assert.strictEqual(f.health.failingStreak, 3);
  assert.strictEqual(f.health.lastExit, 1); assert.strictEqual(f.health.lastOutput, "curl: (7) refused");
  assert.strictEqual(f.health.lastAt, Date.UTC(2026, 9, 24, 10, 0, 30));
  assert.strictEqual(P.parseFacts(JSON.stringify({health: null})).health, null);
}

// problem reports: home, user, remote hosts and non-loopback IPs are redacted
{
  const r = P.redact("Error: open /home/riley/docker/app/compose.yaml: riley denied via ssh://riley@nas.local:22 at 192.168.1.20 and 127.0.0.1", "/home/riley", "riley");
  assert.strictEqual(r, "Error: open ~/docker/app/compose.yaml: <user> denied via ssh://<host>:22 at <ip> and 127.0.0.1");
}
