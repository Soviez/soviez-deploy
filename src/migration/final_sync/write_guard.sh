# shellcheck shell=bash
# Application write-freeze enforcement: exact Production write-guard HTTP proxy.
# Does not stop PostgreSQL, mutate License/DNS, or freeze unrelated tenants.

soviez_migration_freeze_guard_dir() {
  local op_id="$1"
  printf '%s/write_guard\n' "$(soviez_migration_freeze_dir "$op_id")"
}

soviez_migration_freeze_guard_script() {
  local guard_dir="$1"
  cat > "$guard_dir/write_guard.py" <<'PY'
#!/usr/bin/env python3
"""Exact-operation write guard for Phase 19 source freeze certification.

Listens on loopback. GET/HEAD always allowed (read-only).
POST/PUT/PATCH/DELETE denied with HTTP 503 while WRITE_FREEZE.active exists
for this exact operation. Optional upstream ERP is proxied for allowed methods.
"""
import http.server
import json
import os
import socketserver
import urllib.request
import urllib.error
from pathlib import Path

MARKER = Path(os.environ["SOVIEZ_FREEZE_MARKER"])
UPSTREAM = os.environ.get("SOVIEZ_FREEZE_UPSTREAM", "").rstrip("/")
PORT = int(os.environ["SOVIEZ_FREEZE_PORT"])
OP_ID = os.environ["SOVIEZ_OP"]
PROD_ID = os.environ.get("SOVIEZ_PROD", "")
READY = Path(os.environ["SOVIEZ_FREEZE_READY"])
STATE = Path(os.environ["SOVIEZ_FREEZE_GUARD_STATE"])

WRITE_METHODS = {"POST", "PUT", "PATCH", "DELETE"}

def freeze_active():
    return MARKER.exists()

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        return

    def _send(self, code, body, ctype="application/json"):
        data = body if isinstance(body, bytes) else body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("X-Soviez-Write-Freeze", "1" if freeze_active() else "0")
        self.send_header("X-Soviez-Migration-Op", OP_ID)
        self.end_headers()
        self.wfile.write(data)

    def _deny_write(self):
        payload = json.dumps({
            "error": "MIGRATION_SOURCE_FREEZE_ACTIVE",
            "operation_id": OP_ID,
            "production_id": PROD_ID,
            "message": "Business writes are temporarily blocked for migration final consistency",
        })
        self._send(503, payload)

    def _proxy_or_ok(self):
        if UPSTREAM:
            url = UPSTREAM + self.path
            req = urllib.request.Request(url, method=self.command)
            length = int(self.headers.get("Content-Length") or 0)
            data = self.rfile.read(length) if length else None
            if data is not None:
                req.data = data
            for h in ("Content-Type", "Cookie", "Authorization"):
                if h in self.headers:
                    req.add_header(h, self.headers[h])
            try:
                with urllib.request.urlopen(req, timeout=30) as resp:
                    body = resp.read()
                    self.send_response(resp.status)
                    self.send_header("Content-Type", resp.headers.get("Content-Type", "text/html"))
                    self.send_header("Content-Length", str(len(body)))
                    self.send_header("X-Soviez-Write-Freeze", "0")
                    self.end_headers()
                    self.wfile.write(body)
            except urllib.error.HTTPError as e:
                body = e.read()
                self._send(e.code, body, e.headers.get("Content-Type", "text/html"))
            except Exception as e:
                self._send(502, json.dumps({"error": "upstream_failed", "detail": str(e)}))
            return
        # Local probe endpoint (no upstream ERP)
        if self.path.startswith("/web/login") or self.path == "/":
            self._send(200, "<html><body>Soviez source probe login</body></html>", "text/html")
            return
        if self.path.startswith("/soviez/write-probe"):
            self._send(200, json.dumps({"ok": True, "write": True, "operation_id": OP_ID}))
            return
        self._send(200, json.dumps({"ok": True, "method": self.command, "path": self.path}))

    def do_GET(self):
        self._proxy_or_ok()

    def do_HEAD(self):
        self._proxy_or_ok()

    def do_POST(self):
        if freeze_active():
            self._deny_write()
            return
        self._proxy_or_ok()

    def do_PUT(self):
        if freeze_active():
            self._deny_write()
            return
        self._proxy_or_ok()

    def do_PATCH(self):
        if freeze_active():
            self._deny_write()
            return
        self._proxy_or_ok()

    def do_DELETE(self):
        if freeze_active():
            self._deny_write()
            return
        self._proxy_or_ok()

class ReuseTCPServer(socketserver.TCPServer):
    allow_reuse_address = True

STATE.write_text(json.dumps({
    "operation_id": OP_ID,
    "production_id": PROD_ID,
    "port": PORT,
    "upstream": UPSTREAM,
    "mode": "application_write_guard",
}))
with ReuseTCPServer(("127.0.0.1", PORT), Handler) as httpd:
    READY.write_text("1")
    httpd.serve_forever()
PY
  chmod +x "$guard_dir/write_guard.py"
}

soviez_migration_freeze_guard_start() {
  local pair_id="$1" op_id="$2" production_id="${3:-}"
  local dir guard_dir port marker
  dir="$(soviez_migration_freeze_dir "$op_id")"
  guard_dir="$(soviez_migration_freeze_guard_dir "$op_id")"
  mkdir -p "$guard_dir"
  marker="$dir/WRITE_FREEZE.active"
  port="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
  soviez_migration_freeze_guard_script "$guard_dir"
  rm -f "$guard_dir/ready"
  SOVIEZ_FREEZE_MARKER="$marker" \
    SOVIEZ_FREEZE_UPSTREAM="${SOVIEZ_MIG_FREEZE_UPSTREAM:-}" \
    SOVIEZ_FREEZE_PORT="$port" \
    SOVIEZ_OP="$op_id" \
    SOVIEZ_PROD="$production_id" \
    SOVIEZ_FREEZE_READY="$guard_dir/ready" \
    SOVIEZ_FREEZE_GUARD_STATE="$guard_dir/state.json" \
    python3 "$guard_dir/write_guard.py" >/dev/null 2>"$guard_dir/guard.err" &
  echo $! > "$guard_dir/guard.pid"
  local i
  for i in $(seq 1 50); do
    [[ -f "$guard_dir/ready" ]] && break
    sleep 0.1
  done
  [[ -f "$guard_dir/ready" ]] || return 1
  printf '{"port":%s,"url":"http://127.0.0.1:%s","mode":"application_write_guard"}\n' "$port" "$port" \
    > "$guard_dir/endpoint.json"
  cat "$guard_dir/endpoint.json"
}

soviez_migration_freeze_guard_stop() {
  local op_id="$1"
  local guard_dir pid
  guard_dir="$(soviez_migration_freeze_guard_dir "$op_id")"
  if [[ -f "$guard_dir/guard.pid" ]]; then
    pid="$(cat "$guard_dir/guard.pid" 2>/dev/null || true)"
    [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    rm -f "$guard_dir/guard.pid" "$guard_dir/ready"
  fi
}

soviez_migration_freeze_write_probe() {
  local op_id="$1" method="${2:-POST}"
  local ep url code
  ep="$(soviez_migration_freeze_guard_dir "$op_id")/endpoint.json"
  [[ -f "$ep" ]] || { printf '{"error":"no_guard"}\n'; return 2; }
  url="$(soviez_json_get "$(cat "$ep")" url)/soviez/write-probe"
  code="$(curl -s -o /tmp/soviez-freeze-probe-$$.out -w '%{http_code}' -X "$method" "$url" || echo 000)"
  printf '{"http_code":%s,"body":' "$code"
  cat /tmp/soviez-freeze-probe-$$.out 2>/dev/null || printf 'null'
  printf '}\n'
  rm -f /tmp/soviez-freeze-probe-$$.out
  [[ "$code" == "200" || "$code" == "503" ]]
}

soviez_migration_freeze_watchdog_standalone() {
  # Independent watchdog process with exact ownership checks
  local pair_id="$1" op_id="$2" timeout="${3:-900}"
  local dir path
  dir="$(soviez_migration_freeze_dir "$op_id")"
  path="$(soviez_migration_freeze_state_path "$op_id")"
  mkdir -p "$dir"
  (
    sleep "$timeout"
    if [[ ! -f "$path" ]]; then
      exit 0
    fi
    local stored_op stored_pair released
    stored_op="$(soviez_json_get "$(cat "$path")" operation_id 2>/dev/null || true)"
    stored_pair="$(soviez_json_get "$(cat "$path")" migration_pair_id 2>/dev/null || true)"
    released="$(soviez_json_get "$(cat "$path")" released 2>/dev/null || echo false)"
    if [[ "$stored_op" != "$op_id" || "$stored_pair" != "$pair_id" ]]; then
      printf 'ownership_mismatch\n' > "$dir/watchdog_denied"
      exit 1
    fi
    if [[ "$released" != "true" && "$released" != "True" ]]; then
      touch "$dir/timed_out"
      soviez_migration_freeze_release "$pair_id" "$op_id" "timeout" || true
      printf 'MIGRATION_SOURCE_FREEZE_TIMEOUT\n' > "$dir/failure_code"
    fi
  ) &
  echo $! > "$dir/watchdog.pid"
}
