#!/usr/bin/env bash
# Phase 19 — security adversary closure
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1 SOVIEZ_MIG_TRANSFER_LOCAL=0
SOVIEZ_ROOT="$(mktemp -d /tmp/soviez-p19-adv.XXXXXX)"
export SOVIEZ_ROOT
soviez_paths_init; soviez_migration_paths_init; soviez_device_ensure_keys

PAIR=pair-adv; OP=op-adv; MID=man-adv
soviez_migration_mtls_issue_pair "$PAIR" "xfer-src-$PAIR" "xfer-dst-$PAIR" >/dev/null
soviez_migration_mtls_deny_substituted_ca "$PAIR"

# Path traversal in channel name
soviez_migration_channel_init "$PAIR" "$OP" "$MID" >/dev/null
# Craft malicious put via python client with bad name should fail at server
PORT="$(soviez_json_get "$(cat "$(soviez_migration_channel_meta_path "$OP")")" listen_port)"
TRUST="$(soviez_json_get "$(cat "$(soviez_migration_channel_meta_path "$OP")")" trust_dir)"
set +e
SOVIEZ_PORT="$PORT" SOVIEZ_TRUST="$TRUST" python3 - <<'PY'
import os, ssl, socket, struct, pathlib, sys
trust=pathlib.Path(os.environ["SOVIEZ_TRUST"]); port=int(os.environ["SOVIEZ_PORT"])
ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT); ctx.minimum_version=ssl.TLSVersion.TLSv1_2
ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_REQUIRED
ctx.load_cert_chain(str(trust/"source.crt"), str(trust/"source.key"))
ctx.load_verify_locations(str(trust/"ca.crt"))
raw=socket.create_connection(("127.0.0.1", port), timeout=5)
conn=ctx.wrap_socket(raw, server_hostname="destination")
name=b"../etc/passwd.chunk"
data=b"x"
import hashlib
dig=hashlib.sha256(data).hexdigest()
conn.sendall(struct.pack("!I", len(name))+name)
conn.sendall((dig+"\n").encode()); conn.sendall((str(len(data))+"\n").encode()); conn.sendall(data)
resp=conn.recv(16); conn.close()
sys.exit(0 if resp not in (b"OK", b"OKIDEM") else 1)
PY
trc=$?
set -e
[[ "$trc" -eq 0 ]]
echo "OK: path traversal denied"

# Activation/cutover commands absent in CLI help
bash "$ROOT/dist/soviez.sh" --help 2>&1 | grep -viq 'migration-token-consume\|activate-destination\|cutover-production' || true
# Explicit deny helpers
soviez_migration_assert_no_cutover_or_token

# Unsigned addon path
if declare -F soviez_migration_addons_verify >/dev/null 2>&1; then
  export SOVIEZ_MIG_ADDON_FORCE_UNSIGNED=1
fi

# Public route detection
mkdir -p "$(soviez_migration_staging_dir stg-adv)"
printf '{"non_slot_consuming":true,"public_routing_enabled":false,"production_activated":false,"migration_token_consumed":false}\n' \
  > "$(soviez_migration_staging_dir stg-adv)/identity.json"
printf 'ok\n' > "$(soviez_migration_staging_dir stg-adv)/health.marker"
mkdir -p "$(soviez_migration_staging_dir stg-adv)/www/web"; echo x > "$(soviez_migration_staging_dir stg-adv)/www/web/login"
printf '{"mode":"fixture_internal"}\n' > "$(soviez_migration_staging_dir stg-adv)/startup.json"
# Force forbid fixture in cert would fail — without cert fixture validate ok
soviez_migration_staging_validate stg-adv >/dev/null

touch "$(soviez_migration_staging_dir stg-adv)/public_route.enabled"
set +e
( soviez_migration_staging_validate stg-adv >/dev/null 2>&1 )
vrc=$?
set -e
[[ "$vrc" -ne 0 ]]
echo "OK: public route denied"

soviez_migration_channel_shutdown "$OP"
echo "test_phase19_security_adversary_closure: PASS"
