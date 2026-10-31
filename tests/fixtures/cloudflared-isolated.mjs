// Run only inside a fresh Linux network namespace with loopback enabled.
// A fake edge inspects HTTP/2 SETTINGS; no Cloudflare account/edge is contacted.
import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { readlinkSync, writeFileSync } from 'node:fs';
import http from 'node:http';
import http2 from 'node:http2';
import net from 'node:net';
import { join } from 'node:path';
import tls from 'node:tls';
import { setTimeout as delay } from 'node:timers/promises';

assert.equal(process.platform, 'linux', 'Linux network isolation required');
assert.notEqual(readlinkSync('/proc/self/ns/net'), readlinkSync('/proc/1/ns/net'), 'Do not run in host network namespace');
const interfaces = spawnSync('ip', ['-j', 'address'], { encoding: 'utf8' });
assert.equal(interfaces.status, 0);
assert.ok(JSON.parse(interfaces.stdout).every(iface => iface.ifname === 'lo'), 'Only loopback may exist');
const [binary, core, dir] = process.argv.slice(2);
assert.ok(binary && core && dir);
const fixtureEnv = { PATH: process.env.PATH, HOME: dir, XDG_CONFIG_HOME: dir, XDG_CACHE_HOME: dir };
const sockets = new Set(), sessions = new Set();
let child;
const watchdog = setTimeout(() => { console.error('[cloudflared-isolated] timeout'); child?.kill('SIGKILL'); process.exit(1); }, 25_000);
function own(socket) { sockets.add(socket); socket.on('close', () => sockets.delete(socket)); return socket; }
async function listen(server) {
    await new Promise((resolve, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolve); });
    return server.address().port;
}
const edge = tls.createServer({ ALPNProtocols: ['h2'] });
try {
    const result = spawnSync(core, ['generate', 'tls-keypair', 'h2.cftunnel.com', '-m', '30'], { encoding: 'utf8', timeout: 5000, env: fixtureEnv });
    assert.equal(result.status, 0);
    const cert = result.stdout.match(/-----BEGIN CERTIFICATE-----[\s\S]+?-----END CERTIFICATE-----/)[0];
    const key = result.stdout.match(/-----BEGIN PRIVATE KEY-----[\s\S]+?-----END PRIVATE KEY-----/)[0];
    const certPath = join(dir, 'fake-edge-cert.pem');
    const configPath = join(dir, 'fake-tunnel.yml');
    writeFileSync(certPath, cert, { mode: 0o600 });
    writeFileSync(configPath, '{}\n', { mode: 0o600 });
    edge.setSecureContext({ cert, key });
    edge.on('connection', own);
    edge.on('tlsClientError', () => {});
    const settings = new Promise((resolve, reject) => {
        edge.on('secureConnection', socket => {
            // cloudflared initiates TLS but serves HTTP/2; the fake edge is the
            // HTTP/2 client, just like the official connection settings test.
            const session = http2.connect('http://fake-edge.invalid', { createConnection: () => socket });
            sessions.add(session);
            session.once('remoteSettings', resolve);
            session.once('error', reject);
        });
    });
    settings.catch(() => {});
    const edgePort = await listen(edge);
    const reservation = net.createServer();
    const metricsPort = await listen(reservation);
    await new Promise(resolve => reservation.close(resolve));
    const token = Buffer.from(JSON.stringify({ a: 'isolated-fixture-account', t: '11111111-1111-4111-8111-111111111111', s: Buffer.alloc(32, 7).toString('base64') })).toString('base64');
    child = spawn(binary, ['tunnel', '--config', configPath, '--no-autoupdate', '--edge', `127.0.0.1:${edgePort}`, '--protocol', 'http2',
        '--ha-connections', '1', '--metrics', `127.0.0.1:${metricsPort}`, '--cacert', certPath,
        'run', '--token', token], { stdio: 'ignore', env: fixtureEnv });
    child.on('error', () => {});
    // This synthetic command-line token intentionally tests the upstream fix;
    // production units use --token-file. Never inspect production credentials.
    let body;
    for (let attempt = 0; attempt < 100; attempt++) {
        assert.equal(child.exitCode, null, 'fixture process exited before metrics startup');
        try {
            body = await new Promise((resolve, reject) => {
                const request = http.get(`http://127.0.0.1:${metricsPort}/debug/vars`, response => {
                    let data = ''; response.on('data', chunk => { data += chunk; }); response.once('end', () => resolve(data));
                });
                request.setTimeout(1000, () => request.destroy(new Error('metrics timeout')));
                request.once('error', reject);
            });
            break;
        } catch { await delay(50); }
    }
    assert.ok(body, 'metrics endpoint unavailable');
    const variables = JSON.parse(body);
    assert.ok(!Object.hasOwn(variables, 'cmdline') && !body.includes(token), 'metrics contains synthetic command-line credentials');
    const advertised = await settings;
    assert.equal(advertised.maxConcurrentStreams, 2_147_483_647, 'HTTP/2 concurrent-stream regression');
    console.log('[cloudflared-isolated] PASS: metrics excludes cmdline/token; wire HTTP/2 maxConcurrentStreams=2147483647 (not public tunnel E2E or a load benchmark)');
} finally {
    clearTimeout(watchdog);
    for (const session of sessions) session.destroy();
    for (const socket of sockets) socket.destroy();
    edge.close();
    if (child && child.exitCode === null) {
        child.kill('SIGTERM');
        await Promise.race([new Promise(resolve => child.once('exit', resolve)), delay(1500)]);
        if (child.exitCode === null && child.signalCode === null) child.kill('SIGKILL');
    }
}
