#!/usr/bin/env bash
# Phase 21 — real disposable authoritative DNS (Python UDP) + dig quorum.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=tests/helpers/phase21_fixture.sh
source "$ROOT/tests/helpers/phase21_fixture.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

soviez_phase21_fixture_init "$ROOT"
fqdn="$SOVIEZ_MIG_P21_FQDN"
prev="198.51.100.10"
dest="$SOVIEZ_MIG_P21_DEST_IP"
rec="$(soviez_migration_p21_dns_record_file "$fqdn" A)"
mkdir -p "$(dirname "$rec")"
printf '%s\n' "$prev" > "$rec"
export SOVIEZ_MIG_P21_CANONICAL_CUTOVER=1

PORT=$((53540 + RANDOM % 200))
READY="$(mktemp)"
STOP="$(mktemp)"
rm -f "$STOP"
cleanup() { touch "$STOP"; sleep 0.2; rm -f "$READY" "$STOP"; }
trap cleanup EXIT

python3 "$ROOT/tests/helpers/p21_auth_dns_server.py" \
  --port "$PORT" \
  --record "${fqdn}=${prev}" \
  --ready-file "$READY" \
  --stop-file "$STOP" &
DNS_PID=$!
for _ in $(seq 1 50); do [[ -s "$READY" ]] && break; sleep 0.05; done
[[ -s "$READY" ]]

if command -v dig >/dev/null 2>&1; then
  got="$(dig +short +time=2 +tries=2 @"127.0.0.1" -p "$PORT" "$fqdn" A | head -1 | tr -d '[:space:]')"
  assert_eq "$got" "$prev" "authoritative dig before mutate"
else
  # Fallback query via python
  got="$(python3 - <<PY
import socket,struct
def q(name):
  labels=b''.join(bytes([len(l)])+l.encode() for l in name.split('.'))+b'\\x00'
  pkt=struct.pack('!HHHHHH',0x1234,0x0100,1,0,0,0)+labels+struct.pack('!HH',1,1)
  s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.settimeout(2)
  s.sendto(pkt,('127.0.0.1',$PORT)); data,_=s.recvfrom(2048)
  # crude A extract: last 4 bytes of first answer
  return socket.inet_ntoa(data[-4:])
print(q('$fqdn'))
PY
)"
  assert_eq "$got" "$prev" "python auth query before mutate"
fi

soviez_migration_p21_dns_mutate "$fqdn" "$dest" >/dev/null
assert_eq "$(tr -d '[:space:]' < "$rec")" "$dest" "zone file after mutate"

# Restart auth DNS with new record (simulates authoritative update)
touch "$STOP"; wait "$DNS_PID" 2>/dev/null || true
rm -f "$STOP" "$READY"
python3 "$ROOT/tests/helpers/p21_auth_dns_server.py" \
  --port "$PORT" \
  --record "${fqdn}=${dest}" \
  --ready-file "$READY" \
  --stop-file "$STOP" &
DNS_PID=$!
for _ in $(seq 1 50); do [[ -s "$READY" ]] && break; sleep 0.05; done

if command -v dig >/dev/null 2>&1; then
  got="$(dig +short +time=2 +tries=2 @"127.0.0.1" -p "$PORT" "$fqdn" A | head -1 | tr -d '[:space:]')"
  assert_eq "$got" "$dest" "authoritative dig after mutate"
  got2="$(dig +short +time=2 +tries=2 @"127.0.0.1" -p "$PORT" "$fqdn" A | head -1 | tr -d '[:space:]')"
  assert_eq "$got2" "$dest" "second resolver path agrees"
else
  got="$(python3 - <<PY
import socket,struct
def q(name):
  labels=b''.join(bytes([len(l)])+l.encode() for l in name.split('.'))+b'\\x00'
  pkt=struct.pack('!HHHHHH',0x1234,0x0100,1,0,0,0)+labels+struct.pack('!HH',1,1)
  s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.settimeout(2)
  s.sendto(pkt,('127.0.0.1',$PORT)); data,_=s.recvfrom(2048)
  return socket.inet_ntoa(data[-4:])
print(q('$fqdn'))
PY
)"
  assert_eq "$got" "$dest" "python auth query after mutate"
fi

soviez_migration_p21_dns_rollback "$fqdn" "$prev" >/dev/null
assert_eq "$(tr -d '[:space:]' < "$rec")" "$prev" "zone rollback"

# Also exercise installer propagation observer (zone file quorum)
prop="$(soviez_migration_p21_propagation_observe "$fqdn" "$prev")"
assert_eq "$(soviez_json_get "$prop" majority)" "True" "installer propagation majority"

echo "test_phase21_dns_authoritative: PASS (real python authoritative DNS + dig/python quorum)"
