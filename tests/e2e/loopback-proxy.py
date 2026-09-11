#!/usr/bin/env python3
"""Non-root, loopback-only SOCKS test using a production-generated configuration."""

import argparse
import http.server
import json
import os
from pathlib import Path
import secrets
import socket
import struct
import subprocess
import tempfile
import threading
import time


def receive(sock, length):
    data = b""
    while len(data) < length:
        part = sock.recv(length - len(data))
        if not part:
            raise RuntimeError("unexpected EOF")
        data += part
    return data


def authenticate(sock, username, password):
    sock.sendall(b"\x05\x01\x02")
    assert receive(sock, 2) == b"\x05\x02", "SOCKS authentication not negotiated"
    user, passwd = username.encode(), password.encode()
    assert len(user) < 256 and len(passwd) < 256
    sock.sendall(b"\x01" + bytes([len(user)]) + user + bytes([len(passwd)]) + passwd)
    return receive(sock, 2)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core", required=True)
    args = parser.parse_args()
    if not hasattr(os, "geteuid") or os.geteuid() == 0:
        parser.error("run as a non-root Linux user")
    core = str(Path(args.core).resolve(strict=True))
    root = Path(__file__).resolve().parents[2]
    generation = r'''
set -eo pipefail
. src/core/env/defaults.sh
. src/core/node/protocol.sh
. src/core/node/build.sh
. src/core/node/create.sh
. src/core/query/parse.sh
. tests/fixtures/node-context.sh
get() { query_get "$@"; }
get_ip() { :; }
get_reality_short_id() { :; }
err() { printf '%s\n' "$*" >&2; return 1; }
fixture_node_context Socks
write_create server Socks
printf '%s\n' "$is_new_json"
'''
    config = json.loads(subprocess.check_output(
        ["bash", "-c", generation], cwd=root, timeout=30, text=True))
    inbound = config["inbounds"][0]
    assert inbound["type"] == "socks"
    username = inbound["users"][0]["username"]
    password = inbound["users"][0]["password"]
    token = secrets.token_hex(16).encode()

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            self.send_response(200)
            self.send_header("Content-Length", str(len(token)))
            self.end_headers()
            self.wfile.write(token)

        def log_message(self, *_):
            pass

    with http.server.HTTPServer(("127.0.0.1", 0), Handler) as server:
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        try:
            with socket.socket() as reservation:
                reservation.bind(("127.0.0.1", 0))
                proxy_port = reservation.getsockname()[1]
            inbound.update(listen="127.0.0.1", listen_port=proxy_port)
            with tempfile.TemporaryDirectory(prefix="sb-loopback-") as directory:
                config_path = Path(directory) / "config.json"
                config_path.write_text(json.dumps(config), encoding="utf-8")
                subprocess.run([core, "check", "-c", str(config_path)],
                               check=True, timeout=15, capture_output=True)
                with (Path(directory) / "core.log").open("wb") as log:
                    process = subprocess.Popen([core, "run", "-c", str(config_path)],
                                               stdout=log, stderr=subprocess.STDOUT)
                    try:
                        deadline = time.monotonic() + 10
                        while True:
                            if process.poll() is not None:
                                raise RuntimeError("isolated core exited before readiness")
                            try:
                                probe = socket.create_connection(("127.0.0.1", proxy_port), 1)
                                probe.close()
                                break
                            except ConnectionRefusedError:
                                if time.monotonic() >= deadline:
                                    raise RuntimeError("isolated core readiness timeout")
                                time.sleep(0.1)
                        with socket.create_connection(("127.0.0.1", proxy_port), 3) as sock:
                            assert authenticate(sock, username, "invalid-" + password) != b"\x01\x00", "invalid credentials accepted"
                        with socket.create_connection(("127.0.0.1", proxy_port), 3) as sock:
                            assert authenticate(sock, username, password) == b"\x01\x00", "valid credentials rejected"
                            sock.sendall(b"\x05\x01\x00\x01" + socket.inet_aton("127.0.0.1")
                                         + struct.pack("!H", server.server_port))
                            reply = receive(sock, 4)
                            assert reply[:3] == b"\x05\x00\x00", "SOCKS connect failed"
                            size = {1: 4, 4: 16}.get(reply[3])
                            if reply[3] == 3:
                                size = receive(sock, 1)[0]
                            assert size is not None, "invalid SOCKS address type"
                            receive(sock, size + 2)
                            sock.sendall(b"GET / HTTP/1.0\r\nHost: localhost\r\n\r\n")
                            response = b""
                            while True:
                                chunk = sock.recv(4096)
                                if not chunk:
                                    break
                                response += chunk
                            headers, body = response.split(b"\r\n\r\n", 1)
                            assert headers.startswith(b"HTTP/1.0 200") and body == token, "proxy response mismatch"
                    finally:
                        process.terminate()
                        try:
                            process.wait(timeout=5)
                        except subprocess.TimeoutExpired:
                            process.kill()
                            process.wait(timeout=5)
        finally:
            server.shutdown()
            worker.join(timeout=5)
    print("[loopback-proxy] ok: production SOCKS config, authentication rejection, authenticated HTTP forwarding")


if __name__ == "__main__":
    main()
