#!/usr/bin/env python3
"""Minimal mock SaaS + registry gateway for installer integration tests."""
from __future__ import annotations

import hashlib
import json
import os
import threading
import uuid
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse


def _json_response(handler: BaseHTTPRequestHandler, code: int, payload: dict) -> None:
    body = json.dumps(payload).encode("utf-8")
    handler.send_response(code)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


class MockHandler(BaseHTTPRequestHandler):
    server_version = "SoviezMock/1.0"
    sessions: dict[str, dict] = {}
    approved_devices: set[str] = set()

    def log_message(self, fmt: str, *args) -> None:  # noqa: D401
        # Avoid logging secrets from requests
        msg = fmt % args
        for token in ("credential", "password", "activation_key"):
            if token in msg:
                msg = msg.split("?", 1)[0]
        print(f"[mock] {self.command} {self.path} -> {msg}")

    def _read_json(self) -> dict:
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length else b"{}"
        return json.loads(raw.decode("utf-8") or "{}")

    def do_POST(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        data = self._read_json()

        if path == "/api/installer-auth/device/start":
            device_code = hashlib.sha256(os.urandom(32)).hexdigest()
            session_id = str(uuid.uuid4())
            MockHandler.sessions[device_code] = {"session_id": session_id, "approved": False}
            _json_response(
                self,
                200,
                {
                    "device_code": device_code,
                    "user_code": "TEST-1234",
                    "verification_uri": "http://mock/authorize",
                    "verification_uri_complete": "http://mock/authorize?user_code=TEST-1234",
                    "expires_in": 900,
                    "interval": 1,
                    "session_id": session_id,
                },
            )
            # Auto-approve for tests
            MockHandler.sessions[device_code]["approved"] = True
            return

        if path == "/api/installer-auth/device/token":
            device_code = data.get("device_code", "")
            sess = MockHandler.sessions.get(device_code)
            if not sess:
                _json_response(self, 400, {"error": "invalid_grant"})
                return
            if not sess.get("approved"):
                _json_response(self, 400, {"error": "authorization_pending"})
                return
            _json_response(
                self,
                200,
                {
                    "device_id": f"dev-{device_code[:8]}",
                    "credential_id": f"cred-{device_code[:8]}",
                    "credential": f"opaque-{hashlib.sha256(device_code.encode()).hexdigest()[:24]}",
                    "expires_at": "2099-01-01T00:00:00Z",
                },
            )
            return

        if path == "/api/installer/slots/reserve":
            slot_id = f"slot-{uuid.uuid4()}"
            _json_response(self, 200, {"slot_id": slot_id, "status": "reserved"})
            return

        if path == "/api/installer/registry/releases/resolve":
            digest = "sha256:" + hashlib.sha256(b"release").hexdigest()
            _json_response(
                self,
                200,
                {
                    "release_id": "rel-stable-1",
                    "digest": digest,
                    "signature": "test-signature",
                    "manifest": {"version": "18.0"},
                },
            )
            return

        if path == "/api/installer/registry/pull-sessions":
            digest = data.get("digest", "")
            _json_response(
                self,
                200,
                {
                    "session_id": f"pull-{uuid.uuid4()}",
                    "username": "pull-user",
                    "password": "pull-pass-not-logged",
                    "image_ref": f"registry/mock/soviez-erp@{digest}",
                },
            )
            return

        if path == "/api/installer/registry/pull-sessions/refresh":
            _json_response(self, 200, {"session_id": data.get("session_id"), "status": "refreshed"})
            return

        if path in {
            "/api/installer/slots/instance-provisioned",
            "/api/installer/slots/activation-method",
            "/api/installer/slots/bind-fingerprint",
            "/api/installer/slots/activation-ack",
            "/api/installer/slots/release",
        }:
            _json_response(self, 200, {"ok": True})
            return

        if path == "/api/installer/slots/issue-license":
            _json_response(
                self,
                200,
                {"activation_key": "SOV-MOCK-KEY-0001", "status": "issued"},
            )
            return

        _json_response(self, 404, {"error": "not_found", "path": path})


def main() -> None:
    host = os.environ.get("SOVIEZ_MOCK_HOST", "127.0.0.1")
    port = int(os.environ.get("SOVIEZ_MOCK_PORT", "8765"))
    httpd = HTTPServer((host, port), MockHandler)
    print(f"mock server listening on http://{host}:{port}", flush=True)
    httpd.serve_forever()


if __name__ == "__main__":
    main()
