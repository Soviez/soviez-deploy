# shellcheck shell=bash
# Phase 19 — application-level transfer channel (local filesystem OR real mTLS).

soviez_migration_channel_is_local() {
  # Explicit local flag only — certification forbids it when gates active.
  if [[ "${SOVIEZ_PHASE19_FORBID_LOCAL_TRANSFER:-0}" == "1" || "${SOVIEZ_PHASE19_REQUIRE_REAL_MTLS:-0}" == "1" || "${SOVIEZ_PHASE19_CERTIFICATION:-0}" == "1" ]]; then
    if [[ "${SOVIEZ_MIG_TRANSFER_LOCAL:-0}" == "1" ]]; then
      soviez_migration_die MIGRATION_TRANSFER_CHANNEL_FAILED "local-copy transfer forbidden in certification mode"
    fi
    return 1
  fi
  [[ "${SOVIEZ_MIG_TRANSFER_LOCAL:-0}" == "1" ]]
}

soviez_migration_channel_meta_path() {
  local op_id="$1"
  printf '%s/meta/channel.json\n' "$(soviez_migration_transfer_channel_dir "$op_id")"
}

soviez_migration_channel_receiver_script() {
  local ch_dir="$1"
  cat > "$ch_dir/meta/receiver.py" <<'PY'
import json, os, ssl, socket, hashlib, struct, pathlib, signal, sys

ch = pathlib.Path(os.environ["SOVIEZ_CH"])
trust = pathlib.Path(os.environ["SOVIEZ_TRUST"])
port = int(os.environ["SOVIEZ_PORT"])
inbox = ch / "inbox"
meta = ch / "meta"
replay_path = meta / "replay.json"
ready_path = meta / "receiver.ready"
pid_path = meta / "receiver.pid"
pid_path.write_text(str(os.getpid()))

ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.minimum_version = ssl.TLSVersion.TLSv1_2
ctx.verify_mode = ssl.CERT_REQUIRED
ctx.load_cert_chain(str(trust / "destination.crt"), str(trust / "destination.key"))
ctx.load_verify_locations(str(trust / "ca.crt"))

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.bind(("127.0.0.1", port))
sock.listen(8)
sock.settimeout(1.0)
ready_path.write_text("1")

def handle(conn):
    with conn:
        hdr = b""
        while len(hdr) < 4:
            b = conn.recv(4 - len(hdr))
            if not b:
                return
            hdr += b
        n = struct.unpack("!I", hdr)[0]
        if n <= 0 or n > 256:
            conn.sendall(b"ERRNAME")
            return
        name_b = b""
        while len(name_b) < n:
            b = conn.recv(n - len(name_b))
            if not b:
                return
            name_b += b
        name = name_b.decode("utf-8", "replace")
        if "/" in name or ".." in name or not name.endswith(".chunk"):
            conn.sendall(b"ERRNAME")
            return
        line = b""
        while not line.endswith(b"\n"):
            b = conn.recv(1)
            if not b:
                return
            line += b
        sha_exp = line.strip().decode()
        line = b""
        while not line.endswith(b"\n"):
            b = conn.recv(1)
            if not b:
                return
            line += b
        size = int(line.strip())
        if size < 0 or size > 96 * 1024 * 1024:
            conn.sendall(b"ERRSIZE")
            return
        h = hashlib.sha256()
        left = size
        dest = inbox / name
        tmp = dest.with_suffix(".partial")
        with open(tmp, "wb") as f:
            while left:
                chunk = conn.recv(min(65536, left))
                if not chunk:
                    break
                f.write(chunk)
                h.update(chunk)
                left -= len(chunk)
        dig = h.hexdigest()
        if dig != sha_exp or left != 0:
            try:
                tmp.unlink()
            except OSError:
                pass
            conn.sendall(b"ERRCKSUM")
            return
        replay_id = f"{os.environ['SOVIEZ_OP']}:{name}:{dig}"
        replays = set()
        if replay_path.exists():
            replays = set(replay_path.read_text().splitlines())
        if replay_id in replays:
            try:
                tmp.unlink()
            except OSError:
                pass
            conn.sendall(b"OKIDEM")
            return
        tmp.replace(dest)
        dest.with_suffix(dest.suffix + ".sha256").write_text(dig + "\n")
        with open(replay_path, "a") as rf:
            rf.write(replay_id + "\n")
        conn.sendall(b"OK")

running = True
def stop(*_a):
    global running
    running = False
signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)

while running:
    try:
        c, _ = sock.accept()
    except socket.timeout:
        continue
    except OSError:
        break
    try:
        sc = ctx.wrap_socket(c, server_side=True)
    except ssl.SSLError:
        try:
            c.close()
        except Exception:
            pass
        continue
    try:
        handle(sc)
    finally:
        try:
            sc.close()
        except Exception:
            pass
sock.close()
PY
}

soviez_migration_channel_init() {
  local pair_id="$1" op_id="$2" manifest_id="$3"
  local ch_dir trust_dir mode="mtls" port=""
  soviez_migration_paths_init
  ch_dir="$(soviez_migration_transfer_channel_dir "$op_id")"
  mkdir -p "$ch_dir/inbox" "$ch_dir/outbox" "$ch_dir/meta"
  chmod 700 "$ch_dir" 2>/dev/null || true
  rm -f "$ch_dir/meta/receiver.ready"

  trust_dir=""
  if declare -F soviez_migration_mtls_issue_pair >/dev/null 2>&1; then
    trust_dir="$(soviez_migration_mtls_issue_pair "$pair_id" "xfer-src-$pair_id" "xfer-dst-$pair_id" 2>/dev/null || true)"
  fi

  if soviez_migration_channel_is_local; then
    mode="local_filesystem"
  else
    mode="mtls"
    [[ -n "$trust_dir" && -f "$trust_dir/ca.crt" ]] || \
      soviez_migration_die MIGRATION_TRANSFER_CERTIFICATE_INVALID "Pair mTLS trust material missing for channel"
    port="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
    if [[ ! -f "$ch_dir/meta/receiver.pid" ]] || ! kill -0 "$(cat "$ch_dir/meta/receiver.pid" 2>/dev/null)" 2>/dev/null; then
      soviez_migration_channel_receiver_script "$ch_dir"
      SOVIEZ_CH="$ch_dir" SOVIEZ_TRUST="$trust_dir" SOVIEZ_PORT="$port" \
        SOVIEZ_OP="$op_id" SOVIEZ_MID="$manifest_id" \
        python3 "$ch_dir/meta/receiver.py" >/dev/null 2>"$ch_dir/meta/receiver.err" &
      echo $! > "$ch_dir/meta/receiver.pid"
      local i
      for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
        [[ -f "$ch_dir/meta/receiver.ready" ]] && break
        sleep 0.1
      done
      [[ -f "$ch_dir/meta/receiver.ready" ]] || \
        soviez_migration_die MIGRATION_TRANSFER_CHANNEL_FAILED "mTLS receiver failed to start: $(cat "$ch_dir/meta/receiver.err" 2>/dev/null || true)"
    else
      port="$(soviez_json_get "$(cat "$(soviez_migration_channel_meta_path "$op_id")" 2>/dev/null || echo '{}')" listen_port)"
    fi
  fi

  SOVIEZ_PAIR="$pair_id" SOVIEZ_OP="$op_id" SOVIEZ_MID="$manifest_id" \
    SOVIEZ_CH="$ch_dir" SOVIEZ_TRUST="${trust_dir:-}" SOVIEZ_MODE="$mode" SOVIEZ_PORT="${port:-}" \
    python3 - <<'PY'
import json, os, datetime
doc={
  "schema_version":"soviez.migration_transfer_channel.v1",
  "operation_id": os.environ["SOVIEZ_OP"],
  "migration_pair_id": os.environ["SOVIEZ_PAIR"],
  "manifest_id": os.environ["SOVIEZ_MID"],
  "mode": os.environ["SOVIEZ_MODE"],
  "listen_host": "127.0.0.1" if os.environ["SOVIEZ_MODE"]=="mtls" else "",
  "listen_port": os.environ.get("SOVIEZ_PORT") or "",
  "trust_dir": os.environ.get("SOVIEZ_TRUST") or "",
  "status": "established",
  "tls_min": "1.2",
  "mutual_auth": os.environ["SOVIEZ_MODE"]=="mtls",
  "replay_store": {},
  "created_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
}
open(os.path.join(os.environ["SOVIEZ_CH"],"meta","channel.json"),"w").write(json.dumps(doc, separators=(",", ":")))
print(json.dumps(doc, separators=(",", ":")))
PY
}

soviez_migration_channel_shutdown() {
  local op_id="$1"
  local ch_dir pid_file pid
  ch_dir="$(soviez_migration_transfer_channel_dir "$op_id")"
  pid_file="$ch_dir/meta/receiver.pid"
  if [[ -f "$pid_file" ]]; then
    pid="$(cat "$pid_file" 2>/dev/null || true)"
    if [[ -n "$pid" ]]; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    fi
    rm -f "$pid_file" "$ch_dir/meta/receiver.ready"
  fi
  if [[ -f "$(soviez_migration_channel_meta_path "$op_id")" ]]; then
    SOVIEZ_P="$(soviez_migration_channel_meta_path "$op_id")" python3 - <<'PY'
import json, os
p=os.environ["SOVIEZ_P"]
d=json.load(open(p))
d["status"]="shutdown"
open(p,"w").write(json.dumps(d, separators=(",", ":")))
PY
  fi
}

soviez_migration_channel_put() {
  local op_id="$1" chunk_id="$2" src_file="$3"
  local ch_dir dest replay_id digest mode port trust_dir
  ch_dir="$(soviez_migration_transfer_channel_dir "$op_id")"
  [[ -d "$ch_dir" ]] || soviez_migration_die MIGRATION_TRANSFER_CHANNEL_FAILED "Channel not initialized"
  [[ -f "$src_file" ]] || soviez_migration_die MIGRATION_TRANSFER_CHUNK_INVALID "Missing chunk payload: $src_file"
  digest="$(openssl dgst -sha256 "$src_file" | awk '{print $NF}')"
  replay_id="${op_id}:${chunk_id}.chunk:${digest}"

  mode="$(soviez_json_get "$(cat "$(soviez_migration_channel_meta_path "$op_id")")" mode)"
  if [[ "$mode" == "local_filesystem" ]] || soviez_migration_channel_is_local; then
    dest="$ch_dir/inbox/${chunk_id}.chunk"
    if [[ -f "$ch_dir/meta/replay.json" ]] && grep -qF "$replay_id" "$ch_dir/meta/replay.json" 2>/dev/null; then
      printf '{"chunk_id":"%s","status":"idempotent","sha256":"%s","mode":"local"}\n' "$chunk_id" "$digest"
      return 0
    fi
    cp -f "$src_file" "$dest"
    printf '%s\n' "$digest" > "$dest.sha256"
    printf '%s\n' "$replay_id" >> "$ch_dir/meta/replay.json"
    soviez_migration_bandwidth_throttle_bytes "${SOVIEZ_MIG_RESOURCE_PROFILE:-balanced}" "$(wc -c < "$src_file" | tr -d ' ')"
    printf '{"chunk_id":"%s","status":"received","sha256":"%s","path":"%s","mode":"local"}\n' "$chunk_id" "$digest" "$dest"
    return 0
  fi

  port="$(soviez_json_get "$(cat "$(soviez_migration_channel_meta_path "$op_id")")" listen_port)"
  trust_dir="$(soviez_json_get "$(cat "$(soviez_migration_channel_meta_path "$op_id")")" trust_dir)"
  [[ -n "$port" && -n "$trust_dir" ]] || \
    soviez_migration_die MIGRATION_TRANSFER_CHANNEL_FAILED "mTLS channel missing listen port/trust"
  local put_rc
  if ! put_rc="$(
    SOVIEZ_PORT="$port" SOVIEZ_TRUST="$trust_dir" SOVIEZ_SRC="$src_file" \
      SOVIEZ_NAME="${chunk_id}.chunk" SOVIEZ_DIG="$digest" python3 - <<'PY'
import os, ssl, socket, struct, pathlib, sys
trust = pathlib.Path(os.environ["SOVIEZ_TRUST"])
port = int(os.environ["SOVIEZ_PORT"])
src = pathlib.Path(os.environ["SOVIEZ_SRC"])
name = os.environ["SOVIEZ_NAME"].encode()
dig = os.environ["SOVIEZ_DIG"]
data = src.read_bytes()
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
ctx.minimum_version = ssl.TLSVersion.TLSv1_2
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_REQUIRED
ctx.load_cert_chain(str(trust / "source.crt"), str(trust / "source.key"))
ctx.load_verify_locations(str(trust / "ca.crt"))
raw = socket.create_connection(("127.0.0.1", port), timeout=10)
conn = ctx.wrap_socket(raw, server_hostname="destination")
try:
    conn.sendall(struct.pack("!I", len(name)) + name)
    conn.sendall((dig + "\n").encode())
    conn.sendall((str(len(data)) + "\n").encode())
    conn.sendall(data)
    resp = conn.recv(16)
finally:
    conn.close()
if resp not in (b"OK", b"OKIDEM"):
    sys.stderr.write(f"mTLS put rejected: {resp!r}\n")
    sys.exit(1)
print(resp.decode())
PY
  )"; then
    soviez_migration_die MIGRATION_TRANSFER_CHANNEL_FAILED "mTLS chunk put failed"
  fi
  if [[ "$put_rc" == "OKIDEM" ]] || [[ ! -f "$ch_dir/inbox/${chunk_id}.chunk" ]]; then
    printf '{"chunk_id":"%s","status":"idempotent","sha256":"%s","mode":"mtls"}\n' "$chunk_id" "$digest"
  else
    printf '{"chunk_id":"%s","status":"received","sha256":"%s","mode":"mtls"}\n' "$chunk_id" "$digest"
  fi
  soviez_migration_bandwidth_throttle_bytes "${SOVIEZ_MIG_RESOURCE_PROFILE:-balanced}" "$(wc -c < "$src_file" | tr -d ' ')"
}

soviez_migration_channel_get() {
  local op_id="$1" chunk_id="$2" dest_file="$3"
  local ch_dir src expected actual
  ch_dir="$(soviez_migration_transfer_channel_dir "$op_id")"
  src="$ch_dir/inbox/${chunk_id}.chunk"
  [[ -f "$src" ]] || soviez_migration_die MIGRATION_TRANSFER_CHANNEL_FAILED "Chunk not in channel: $chunk_id"
  expected="$(cat "$src.sha256" 2>/dev/null || true)"
  actual="$(openssl dgst -sha256 "$src" | awk '{print $NF}')"
  [[ -z "$expected" || "$expected" == "$actual" ]] || \
    soviez_migration_die MIGRATION_TRANSFER_CHUNK_CHECKSUM_MISMATCH "Channel get checksum mismatch for $chunk_id"
  mkdir -p "$(dirname "$dest_file")"
  cp -f "$src" "$dest_file"
  printf '{"chunk_id":"%s","status":"fetched","sha256":"%s"}\n' "$chunk_id" "$actual"
}
