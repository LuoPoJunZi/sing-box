// Test-only standard-library fixture. All listeners are bound to 127.0.0.1;
// only child processes and files created by this invocation are cleaned up.
import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { createHash, randomBytes } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import http from 'node:http';
import http2 from 'node:http2';
import https from 'node:https';
import net from 'node:net';
import { join } from 'node:path';
import { Duplex } from 'node:stream';
import tls from 'node:tls';
import { setTimeout as delay } from 'node:timers/promises';

const dir = process.env.UPSTREAM_TEST_DIR;
assert.ok(dir && process.env.CADDY_BIN && process.env.SING_BOX_CORE_BIN, 'Use the opt-in shell entry point');
const children = [];
const sockets = new Set();
const servers = [];
const timers = new Set();
const idleMs = 65_000; // Must exceed the upstream 60-second regression boundary.
const watchdog = setTimeout(() => { console.error('[upstream-runtime] watchdog expired'); cleanup(); process.exit(1); }, 100_000);

function own(socket) {
    sockets.add(socket);
    socket.on('close', () => sockets.delete(socket));
    return socket;
}
function later(fn) {
    const timer = setTimeout(() => { timers.delete(timer); fn(); }, idleMs);
    timers.add(timer);
}
function cleanup() {
    for (const timer of timers) clearTimeout(timer);
    for (const socket of sockets) socket.destroy();
    for (const server of servers) server.close();
    for (const child of children) if (child.exitCode === null) child.kill();
}
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => { cleanup(); process.exit(1); });
async function listen(server) {
    servers.push(server);
    server.on('connection', own);
    await new Promise((resolve, reject) => {
        server.once('error', reject);
        server.listen(0, '127.0.0.1', resolve);
    });
    return server.address().port;
}
async function unusedPort() {
    const reservation = net.createServer();
    const port = await listen(reservation);
    await new Promise(resolve => reservation.close(resolve));
    return port;
}
function run(binary, args) {
    const result = spawnSync(binary, args, { encoding: 'utf8', timeout: 10_000 });
    assert.equal(result.status, 0, result.stderr || result.error?.message);
    return result.stdout;
}
function start(binary, args) {
    const child = spawn(binary, args, { stdio: ['ignore', 'ignore', 'pipe'], windowsHide: true });
    children.push(child);
    child.log = '';
    child.stderr.on('data', chunk => { child.log = (child.log + chunk).slice(-8000); });
    child.on('error', error => { child.startError = error; });
    return child;
}
async function ready(child, port) {
    for (let i = 0; i < 100; i++) {
        assert.ok(!child.startError && child.exitCode === null, child.startError?.message || child.log);
        const success = await new Promise(resolve => {
            const socket = own(net.connect({ host: '127.0.0.1', port }));
            socket.once('connect', () => { socket.destroy(); resolve(true); });
            socket.once('error', () => resolve(false));
        });
        if (success) return;
        await delay(50);
    }
    throw new Error(`Listener not ready: ${port}\n${child.log}`);
}
function httpsStream(port) {
    return new Promise((resolve, reject) => {
        const request = https.request({ host: '127.0.0.1', port, servername: 'example.com', rejectUnauthorized: false,
            path: '/stream', method: 'POST', headers: { host: 'example.com', 'content-length': 1 } }, response => {
            assert.equal(response.statusCode, 200);
            let body = '';
            response.on('data', chunk => { body += chunk; });
            response.once('aborted', () => reject(new Error('HTTP/1.1 stream aborted')));
            response.once('error', reject);
            response.once('end', () => { try { assert.equal(body, 'start\nend\n'); resolve(); } catch (error) { reject(error); } });
        });
        request.once('error', reject);
        request.end('x');
    });
}
function h2Stream(port) {
    return new Promise((resolve, reject) => {
        const session = http2.connect(`https://127.0.0.1:${port}`, { servername: 'example.com', rejectUnauthorized: false });
        own(session);
        session.once('error', reject);
        const stream = session.request({ ':path': '/stream', ':authority': 'example.com', ':method': 'POST' });
        let body = '';
        stream.on('response', headers => { if (headers[':status'] !== 200) reject(new Error('HTTP/2 status')); });
        stream.on('data', chunk => { body += chunk; });
        stream.once('error', reject);
        stream.once('end', () => {
            session.close();
            try { assert.equal(body, 'start\nend\n'); resolve(); } catch (error) { reject(error); }
        });
        stream.end('x');
    });
}
function websocket(port) {
    return new Promise((resolve, reject) => {
        const key = randomBytes(16).toString('base64');
        const socket = own(tls.connect({ host: '127.0.0.1', port, servername: 'example.com', rejectUnauthorized: false }));
        let buffered = Buffer.alloc(0), upgraded = false, echoes = 0;
        const send = () => {
            const mask = randomBytes(4), payload = Buffer.from('ping');
            for (let i = 0; i < payload.length; i++) payload[i] ^= mask[i % 4];
            socket.write(Buffer.concat([Buffer.from([0x81, 0x84]), mask, payload]));
        };
        socket.once('secureConnect', () => socket.write(`GET /ws HTTP/1.1\r\nHost: example.com\r\nConnection: Upgrade\r\nUpgrade: websocket\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: ${key}\r\n\r\n`));
        socket.once('error', reject);
        socket.once('close', () => { if (echoes !== 2) reject(new Error('WebSocket closed before idle roundtrip')); });
        socket.on('data', chunk => {
            try {
                buffered = Buffer.concat([buffered, chunk]);
                if (!upgraded) {
                    const end = buffered.indexOf('\r\n\r\n');
                    if (end < 0) return;
                    const header = buffered.subarray(0, end).toString();
                    assert.match(header, /^HTTP\/1\.1 101/);
                    const accept = createHash('sha1').update(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest('base64');
                    assert.ok(header.includes(accept));
                    buffered = buffered.subarray(end + 4); upgraded = true; send();
                }
                while (buffered.length >= 6) {
                    assert.equal(buffered[0], 0x81); assert.equal(buffered[1], 4);
                    assert.equal(buffered.subarray(2, 6).toString(), 'ping');
                    buffered = buffered.subarray(6); echoes++;
                    if (echoes === 1) later(send);
                    else { socket.destroy(); resolve(); }
                }
            } catch (error) { reject(error); }
        });
    });
}
function probe(port, payload) {
    return new Promise((resolve, reject) => {
        const socket = own(net.connect({ host: '127.0.0.1', port }));
        const chunks = [];
        let settled = false;
        const finish = closed => {
            if (settled) return;
            settled = true; clearTimeout(timeout);
            resolve({ closed, data: Buffer.concat(chunks) }); socket.destroy();
        };
        const timeout = setTimeout(() => finish(false), 3000);
        socket.once('connect', () => socket.write(payload));
        socket.on('data', chunk => chunks.push(chunk));
        socket.once('end', () => finish(true));
        socket.once('error', error => { clearTimeout(timeout); reject(error); });
    });
}
async function clientHello() {
    const chunks = [];
    const transport = new Duplex({ read() {}, write(chunk, _encoding, done) { chunks.push(Buffer.from(chunk)); done(); } });
    const socket = tls.connect({ socket: transport, servername: 'other.invalid', rejectUnauthorized: false });
    socket.on('error', () => {});
    await delay(25); socket.destroy(); transport.destroy();
    assert.ok(chunks.length, 'ClientHello not generated');
    return Buffer.concat(chunks);
}

try {
    const origin = http.createServer((request, response) => {
        request.resume();
        request.once('end', () => {
            response.writeHead(200, { 'content-type': 'text/event-stream' });
            response.write('start\n'); later(() => response.end('end\n'));
        });
    });
    origin.on('upgrade', (request, socket, head) => {
        const accept = createHash('sha1').update(request.headers['sec-websocket-key'] + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest('base64');
        socket.write(`HTTP/1.1 101 Switching Protocols\r\nConnection: Upgrade\r\nUpgrade: websocket\r\nSec-WebSocket-Accept: ${accept}\r\n\r\n`);
        let buffered = head;
        socket.on('data', chunk => {
            buffered = Buffer.concat([buffered, chunk]);
            while (buffered.length >= 10) {
                if (buffered[0] !== 0x81 || buffered[1] !== 0x84) { socket.destroy(); return; }
                const body = Buffer.from(buffered.subarray(6, 10));
                for (let i = 0; i < body.length; i++) body[i] ^= buffered[2 + i % 4];
                buffered = buffered.subarray(10);
                socket.write(Buffer.concat([Buffer.from([0x81, 4]), body]));
            }
        });
    });
    const originPort = await listen(origin);
    const caddyPort = await unusedPort();
    const bundle = run(process.env.SING_BOX_CORE_BIN, ['generate', 'tls-keypair', 'example.com', '-m', '30']);
    const cert = bundle.match(/-----BEGIN CERTIFICATE-----[\s\S]+?-----END CERTIFICATE-----/);
    const key = bundle.match(/-----BEGIN PRIVATE KEY-----[\s\S]+?-----END PRIVATE KEY-----/);
    assert.ok(cert && key, 'Incomplete temporary TLS bundle');
    writeFileSync(join(dir, 'cert.pem'), cert[0]); writeFileSync(join(dir, 'key.pem'), key[0]);
    const config = { admin: { disabled: true }, logging: { logs: { default: { level: 'ERROR' } } }, apps: {
        tls: { certificates: { load_files: [{ certificate: join(dir, 'cert.pem'), key: join(dir, 'key.pem') }] } },
        http: { servers: { test: { listen: [`127.0.0.1:${caddyPort}`], automatic_https: { disable: true },
            tls_connection_policies: [{}], routes: [{ handle: [{ handler: 'reverse_proxy', upstreams: [{ dial: `127.0.0.1:${originPort}` }] }] }] } } }
    } };
    writeFileSync(join(dir, 'caddy.json'), JSON.stringify(config));
    run(process.env.CADDY_BIN, ['validate', '--config', join(dir, 'caddy.json')]);
    const caddy = start(process.env.CADDY_BIN, ['run', '--config', join(dir, 'caddy.json')]);
    await ready(caddy, caddyPort);
    const streams = Promise.all([httpsStream(caddyPort), h2Stream(caddyPort), websocket(caddyPort)]);
    // Attach rejection handling immediately while the Reality checks run.
    streams.catch(() => {});

    const realityPort = await unusedPort();
    const reality = JSON.parse(readFileSync(join(dir, 'reality.json'), 'utf8'));
    reality.inbounds[0].listen = '127.0.0.1'; reality.inbounds[0].listen_port = realityPort;
    reality.inbounds[0].tls.server_name = 'example.com';
    reality.inbounds[0].tls.reality.handshake = { server: '127.0.0.1', server_port: caddyPort };
    writeFileSync(join(dir, 'reality.json'), JSON.stringify(reality));
    run(process.env.SING_BOX_CORE_BIN, ['check', '-c', join(dir, 'reality.json')]);
    const core = start(process.env.SING_BOX_CORE_BIN, ['run', '-c', join(dir, 'reality.json')]);
    await ready(core, realityPort);
    let knownFailures = 0;
    for (const [name, payload] of [['plaintext', Buffer.from('GET / HTTP/1.1\r\nHost: example.com\r\n\r\n')], ['wrong-sni', await clientHello()]]) {
        const direct = await probe(caddyPort, payload);
        assert.ok(direct.closed && direct.data.length, `Invalid control probe: ${name}`);
        const forwarded = await probe(realityPort, payload);
        assert.ok(forwarded.data.length, `No fallback response: ${name}`);
        assert.deepEqual(forwarded.data, direct.data, `Fallback changed response: ${name}`);
        if (!forwarded.closed) {
            knownFailures++;
            console.log(`[upstream-runtime] XFAIL Reality ${name}: response forwarded, no EOF in 3s (#4610, NOT FIXED)`);
        } else console.log(`[upstream-runtime] PASS Reality ${name}: fallback EOF propagated`);
    }
    await streams;
    assert.equal(caddy.exitCode, null, caddy.log);
    console.log('[upstream-runtime] PASS Caddy: HTTP/1.1 POST, HTTP/2 POST and WebSocket survived a 65s idle gap');
    if (process.env.UPSTREAM_REALITY_REQUIRE_FIXED === '1') assert.equal(knownFailures, 0, 'Reality upstream bug is still present');
} catch (error) {
    console.error('[upstream-runtime] FAIL', error);
    process.exitCode = 1;
} finally {
    clearTimeout(watchdog); cleanup();
    await Promise.all(children.map(child => child.exitCode !== null || child.signalCode !== null ? Promise.resolve() : new Promise(resolve => {
        const timer = setTimeout(() => { child.kill('SIGKILL'); resolve(); }, 2000);
        child.once('exit', () => { clearTimeout(timer); resolve(); });
        timer.unref();
    })));
}
