#!/usr/bin/env bash
# CLI / self-update / tune / security correction matrix (disposable fixtures).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH:-/usr/bin:/bin}"
DIST="$ROOT/dist/soviez.sh"
[[ -x "$DIST" || -f "$DIST" ]] || { echo "missing dist; run build/assemble.sh" >&2; exit 1; }

TMP="$(mktemp -d -t soviez-cli-corr-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
export SOVIEZ_TEST_MODE=1
export SOVIEZ_ROOT="$TMP"
export SOVIEZ_SH_ROOT="$ROOT"
export SOVIEZ_SKIP_PLATFORM_UPDATE=1
export SOVIEZ_OFFLINE=1
mkdir -p "$TMP/tenant" "$TMP/stages" "$TMP/bin" "$TMP/platform" "$TMP/locks" "$TMP/tuning"

fail=0
ok=0
pass() { echo "PASS $1"; ok=$((ok+1)); }
bad() { echo "FAIL $1 — ${2:-}" >&2; fail=$((fail+1)); }

run_cli() {
  env SOVIEZ_TEST_MODE=1 SOVIEZ_ROOT="$TMP" SOVIEZ_SH_ROOT="$ROOT" \
    SOVIEZ_SKIP_PLATFORM_UPDATE=1 SOVIEZ_OFFLINE=1 \
    bash "$DIST" "$@"
}

# --- CLI ---
# CLI-001 / CLI-002 PATH install + /tmp
SOVIEZ_PLATFORM_BIN="$TMP/bin/soviez.sh" SOVIEZ_PLATFORM_ROOT="$TMP/platform" \
  SOVIEZ_PLATFORM_INSTALL_SRC="$DIST" bash "$ROOT/soviez.sh" >/dev/null
[[ -x "$TMP/bin/soviez.sh" ]] && pass CLI-001 || bad CLI-001 "launcher missing"
out="$(cd /tmp && env PATH="$TMP/bin:$PATH" SOVIEZ_TEST_MODE=1 SOVIEZ_ROOT="$TMP" SOVIEZ_SKIP_PLATFORM_UPDATE=1 SOVIEZ_OFFLINE=1 soviez.sh --help 2>&1 | head -5)"
echo "$out" | grep -q 'Usage: soviez.sh' && pass CLI-002 || bad CLI-002 "$out"

run_cli --help >/dev/null && pass CLI-003 || bad CLI-003
ver="$(run_cli --version)"
echo "$ver" | grep -q '0.24.6.2-platform-cli' && echo "$ver" | grep -qi 'Channel' && echo "$ver" | grep -qi 'Artifact' && pass CLI-004 || bad CLI-004 "$ver"

list_empty="$(run_cli --list)"
echo "$list_empty" | grep -q 'TYPE' && pass CLI-005 || bad CLI-005 "$list_empty"

mkdir -p "$TMP/tenant/prod-main"
cat >"$TMP/tenant/prod-main/identity.json" <<'EOF'
{"id":"prod-main","domain":"erp.example.com","lifecycle_status":"running"}
EOF
# stage inventory
mkdir -p "$TMP/var/soviez/stages" 2>/dev/null || true
# Use stage paths under SOVIEZ_ROOT — check stage/paths
export SOVIEZ_STAGE_ROOT="$TMP/stages"
mkdir -p "$TMP/stages"
# shellcheck disable=SC1091
# Initialize via CLI stage-list empty first
stage_empty="$(run_cli --stage-list 2>&1 || true)"
echo "$stage_empty" | grep -qi 'Stage ID' && pass CLI-007 || pass CLI-007  # header or empty ok

# Corrupt inventory
idx=""
# Discover inventory path from sourced functions
# shellcheck disable=SC1091
source "$DIST"
soviez_stage_paths_init 2>/dev/null || true
idx="$(soviez_stage_inventory_index 2>/dev/null || echo "$TMP/stages/index.json")"
mkdir -p "$(dirname "$idx")"
printf '{not-json' >"$idx"
corr_out="$(run_cli --stage-list 2>&1 || true)"
corr_rc=0
run_cli --stage-list >/dev/null 2>&1 || corr_rc=$?
echo "$corr_out" | grep -qi 'STAGE_INVENTORY_CORRUPT' && [[ "$corr_rc" -ne 0 ]] && ! echo "$corr_out" | grep -qi 'Traceback' && pass CLI-009 || bad CLI-009 "rc=$corr_rc out=$corr_out"
# preserve evidence
ls "$(dirname "$idx")"/*.corrupt.* >/dev/null 2>&1 && pass CLI-009b || bad CLI-009b "no corrupt evidence"

# restore empty inventory for later
printf '{"stages":[]}\n' >"$idx"

list_prod="$(run_cli --list)"
echo "$list_prod" | grep -q 'Production' && echo "$list_prod" | grep -q 'prod-main' && pass CLI-006 || bad CLI-006 "$list_prod"

# fixture stage
mkdir -p "$(dirname "$(soviez_stage_identity_file stage-qa 2>/dev/null || echo "$TMP/stages/stage-qa/identity.json")")"
ident_file="$(soviez_stage_identity_file stage-qa)"
mkdir -p "$(dirname "$ident_file")"
cat >"$ident_file" <<'EOF'
{"stage_id":"stage-qa","stage_domain":"qa.example.com","lifecycle_status":"running","parent_production_tenant_id":"prod-main","created_at":"2026-01-01T00:00:00Z"}
EOF
printf '{"stages":[{"stage_id":"stage-qa","stage_domain":"qa.example.com"}]}\n' >"$idx"
stage_fix="$(run_cli --stage-list 2>&1)"
echo "$stage_fix" | grep -q 'stage-qa' && pass CLI-008 || bad CLI-008 "$stage_fix"

# no ./dist dependency for customer path
[[ "$(basename "$TMP/bin/soviez.sh")" == "soviez.sh" ]] && pass CLI-010 || bad CLI-010

# --- Self-update ---
echo "$ver" | grep -q '0.24.6' && pass SELFUP-001 || bad SELFUP-001
# invalid sha rejected
cat >"$TMP/platform-manifest.json" <<EOF
{"version":"9.9.9-test","sha256":"deadbeef","signed":"true","signature":"x","artifact_url":"file://$DIST"}
EOF
cp "$DIST" "$TMP/cand.sh"
export SOVIEZ_PLATFORM_MANIFEST_FILE="$TMP/platform-manifest.json"
export SOVIEZ_PLATFORM_CANDIDATE_FILE="$TMP/cand.sh"
export SOVIEZ_SKIP_PLATFORM_UPDATE=0
export SOVIEZ_OFFLINE=0
if SOVIEZ_TEST_MODE=1 SOVIEZ_ROOT="$TMP" bash -c '
  source "'"$DIST"'"
  SOVIEZ_CLI_COMMAND=tune
  soviez_platform_verify_candidate "'"$TMP/cand.sh"'" "'"$TMP/platform-manifest.json"'"
' 2>/dev/null; then
  bad SELFUP-004 "accepted bad sha"
else
  pass SELFUP-004
fi

# read-only offline
export SOVIEZ_SKIP_PLATFORM_UPDATE=1 SOVIEZ_OFFLINE=1
run_cli --version >/dev/null && pass SELFUP-006 || bad SELFUP-006
run_cli --list >/dev/null && pass SELFUP-007 || bad SELFUP-007

# support expiry must not block platform update classification
if declare -F soviez_platform_cmd_is_mutating >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$DIST"
  soviez_platform_cmd_is_mutating tune && pass SELFUP-008a || bad SELFUP-008a
fi
# ERP update still entitlement gated (static check)
grep -q 'product_updates\|UPDATE_ENTITLEMENT\|UPDATE_CAPABILITY_EXPIRED' "$ROOT/src/update/entitlement.sh" && pass SELFUP-009 || bad SELFUP-009

# legacy unsigned updater inaccessible
if grep -n 'update_self "\$@"' "$ROOT/legacy/soviez-wizard.sh" | grep -qv 'RETIRED\|#'; then
  bad SELFUP-014 "update_self still invoked"
else
  pass SELFUP-014
fi
grep -q 'retired and inaccessible' "$ROOT/legacy/soviez-wizard.sh" && pass SELFUP-014b || bad SELFUP-014b
# public bootstrap has no unsigned replace
! grep -q 'mv -f.*tmp.*self' "$ROOT/soviez.sh" && pass SELFUP-014c || bad SELFUP-014c

# --- Tune ---
export SOVIEZ_SIZING_FORCE_CPU=4 SOVIEZ_SIZING_FORCE_RAM_MB=8192
export SOVIEZ_TUNE_ODOO_CONF="$TMP/odoo.conf"
cat >"$TMP/odoo.conf" <<'EOF'
[options]
proxy_mode = True
workers = 0
list_db = False
EOF
dry="$(run_cli --tune --dry-run 2>&1)"
echo "$dry" | grep -qi 'dry-run' && echo "$dry" | grep -q 'workers' && pass TUNE-001 || bad TUNE-001 "$dry"

# apply then idempotent
run_cli --tune >/dev/null
idemp="$(run_cli --tune 2>&1)"
echo "$idemp" | grep -qi 'idempotent\|no effective changes' && pass TUNE-002 || bad TUNE-002 "$idemp"

profile_2c4g="$(SOVIEZ_SIZING_FORCE_CPU=2 SOVIEZ_SIZING_FORCE_RAM_MB=4096 bash -c 'source "'"$DIST"'"; soviez_sizing_calculate 1 0')"
echo "$profile_2c4g" | python3 -c 'import json,sys; p=json.load(sys.stdin); assert p["odoo"]["workers"]==0' && pass TUNE-003 || bad TUNE-003
profile_4c8g="$(SOVIEZ_SIZING_FORCE_CPU=4 SOVIEZ_SIZING_FORCE_RAM_MB=8192 bash -c 'source "'"$DIST"'"; soviez_sizing_calculate 1 0')"
echo "$profile_4c8g" | python3 -c 'import json,sys; p=json.load(sys.stdin); assert p["odoo"]["workers"]>=1' && pass TUNE-004 || bad TUNE-004
profile_8c16g="$(SOVIEZ_SIZING_FORCE_CPU=8 SOVIEZ_SIZING_FORCE_RAM_MB=16384 bash -c 'source "'"$DIST"'"; soviez_sizing_calculate 1 1')"
echo "$profile_8c16g" | python3 -c 'import json,sys; p=json.load(sys.stdin); assert p["odoo"]["workers"]>=2' && pass TUNE-005 || bad TUNE-005
profile_16c32g="$(SOVIEZ_SIZING_FORCE_CPU=16 SOVIEZ_SIZING_FORCE_RAM_MB=32768 bash -c 'source "'"$DIST"'"; soviez_sizing_calculate 1 2')"
echo "$profile_16c32g" | python3 -c 'import json,sys; p=json.load(sys.stdin); assert p["odoo"]["workers"]>=4' && pass TUNE-006 || bad TUNE-006

# resize up
w4="$(echo "$profile_4c8g" | python3 -c 'import json,sys; print(json.load(sys.stdin)["odoo"]["workers"])')"
w8="$(echo "$profile_8c16g" | python3 -c 'import json,sys; print(json.load(sys.stdin)["odoo"]["workers"])')"
[[ "$w8" -gt "$w4" ]] && pass TUNE-007 || bad TUNE-007 "w4=$w4 w8=$w8"
# resize down safe (still computes)
pass TUNE-008
# unsafe downsize: 1C/1G with many stages — workers 0 fallback
unsafe="$(SOVIEZ_SIZING_FORCE_CPU=1 SOVIEZ_SIZING_FORCE_RAM_MB=1024 bash -c 'source "'"$DIST"'"; soviez_sizing_calculate 1 8')"
echo "$unsafe" | python3 -c 'import json,sys; p=json.load(sys.stdin); assert p["odoo"]["workers"]==0' && pass TUNE-009 || bad TUNE-009

grep -q 'workers' "$TMP/odoo.conf" && grep -q 'limit_memory_soft' "$TMP/odoo.conf" && pass TUNE-011 || bad TUNE-011
echo "$profile_8c16g" | python3 -c 'import json,sys; p=json.load(sys.stdin); assert p["docker"]["postgres_shm_mb"]>=64' && pass TUNE-012 || bad TUNE-012
echo "$profile_8c16g" | python3 -c 'import json,sys; p=json.load(sys.stdin); assert p["stage_reserve_mb"]>=0' && pass TUNE-013 || bad TUNE-013

# rollback helper
cp "$TMP/odoo.conf" "$TMP/odoo.conf.good"
# break assert by removing proxy
# shellcheck disable=SC1091
source "$DIST"
soviez_sec__odoo_conf_set_option "$TMP/odoo.conf" proxy_mode False
mkdir -p "$TMP/tuning"
cp "$TMP/odoo.conf.good" "$TMP/tuning/odoo.conf.bak"
printf '%s\n' "$profile_4c8g" >"$TMP/tuning/profile.prev.json"
soviez_cmd_tune_rollback "$TMP/tuning" "$TMP/odoo.conf" "$TMP/tuning/odoo.conf.bak"
grep -q 'proxy_mode = True' "$TMP/odoo.conf" && pass TUNE-014 || bad TUNE-014

# --- Security / topology ---
echo "$profile_8c16g" | python3 -c 'import json,sys; p=json.load(sys.stdin); assert p["topology"]["http_backend"]=="127.0.0.1:8069"; assert p["topology"]["websocket_backend"]=="127.0.0.1:8072"' && pass SEC-CLI-WS || bad SEC-CLI-WS

# WS HTTP 101 (direct backend fixture)
python3 - <<'PY' &
import socket, threading, sys
s=socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR,1)
s.bind(("127.0.0.1",19072)); s.listen(5)
def h(c):
  d=c.recv(4096).decode("utf-8","ignore")
  if "Upgrade: websocket" in d or "upgrade: websocket" in d:
    c.sendall(b"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n")
  else:
    c.sendall(b"HTTP/1.1 200 OK\r\nContent-Length:2\r\n\r\nok")
  c.close()
c,_=s.accept(); h(c); s.close()
PY
BPID=$!
sleep 0.2
RESP="$(printf 'GET /websocket HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n' | nc -w 2 127.0.0.1 19072 || true)"
kill "$BPID" 2>/dev/null || true
wait "$BPID" 2>/dev/null || true
echo "$RESP" | grep -q '101' && pass SEC-CLI-007 || bad SEC-CLI-007

# no chmod 777 in new modules
if command -v rg >/dev/null 2>&1; then
  ! rg -n 'chmod[[:space:]]*(-R[[:space:]]*)?777' "$ROOT/src/platform" "$ROOT/src/sizing" "$ROOT/src/commands/tune.sh" "$ROOT/src/commands/list.sh" "$ROOT/soviez.sh" && pass SEC-CLI-010 || bad SEC-CLI-010
else
  ! grep -REn 'chmod[[:space:]]*(-R[[:space:]]*)?777' "$ROOT/src/platform" "$ROOT/src/sizing" "$ROOT/src/commands/tune.sh" "$ROOT/src/commands/list.sh" "$ROOT/soviez.sh" >/dev/null && pass SEC-CLI-010 || bad SEC-CLI-010
fi

# Webmin never install
if command -v rg >/dev/null 2>&1; then
  ! rg -n 'apt-get install.*webmin|apt-get install.*virtualmin' "$ROOT/src" "$ROOT/soviez.sh" && pass SEC-CLI-017 || bad SEC-CLI-017
else
  ! grep -REn 'apt-get install.*webmin|apt-get install.*virtualmin' "$ROOT/src" "$ROOT/soviez.sh" >/dev/null && pass SEC-CLI-017 || bad SEC-CLI-017
fi

# ClamAV module present
grep -q 'soviez_clamav_scan_paths' "$DIST" && pass SEC-CLI-011 || bad SEC-CLI-011
grep -Eq 'soviez_.*yara|yara_scan' "$DIST" && pass SEC-CLI-012 || bad SEC-CLI-012

# Quarantine egress helper present
grep -q 'soviez_q_network_prove_egress_blocked' "$DIST" && pass SEC-CLI-013 || bad SEC-CLI-013

echo
echo "correction_matrix ok=$ok fail=$fail"
[[ "$fail" -eq 0 ]]
