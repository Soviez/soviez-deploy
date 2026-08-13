#!/usr/bin/env bash
# Isolated Phase-8 ERP ORM E2E (disposable test keys only).
# Workspace under /tmp — never under git. Keys shredded on exit.
set -euo pipefail

IMG_BASE="soviez/soviez-erp@sha256:228cd4d4d3c88400b5fb0d7dd5092dc2328ed21e2646586244adbc49fda591fc"
WORK="$(mktemp -d /tmp/soviez-p8-erp-e2e-XXXXXX)"
NET="soviez-p8-net-$$"
PG="soviez-p8-pg-$$"
WEB="soviez-p8-web-$$"
IMG_TAG="soviez-p8-erp-test:local"
DB_NAME="soviez_p8"
MIG_SECRET="phase8-e2e-migration-secret-$(openssl rand -hex 16)"
DB_PASS="$(openssl rand -hex 16)"
EVIDENCE_DIR="/Volumes/PortableSSD/soviez-project/soviez-sh/docs/evidence/phase-08-new-connected-activation"
RESULT_FILE="${EVIDENCE_DIR}/ERP_ORM_E2E.md"
SRC_PY="/Volumes/PortableSSD/soviez-project/Soviez ERP/addons/local_license_guard/tools/license_tools.py"

cleanup() {
  set +e
  docker rm -f "$WEB" "$PG" >/dev/null 2>&1
  docker network rm "$NET" >/dev/null 2>&1
  docker rmi "$IMG_TAG" >/dev/null 2>&1
  if [[ -d "$WORK" ]]; then
    find "$WORK" -type f -exec shred -u {} \; 2>/dev/null || find "$WORK" -type f -delete
    rm -rf "$WORK"
  fi
}
trap cleanup EXIT

mkdir -p "$WORK"
chmod 700 "$WORK"
cd "$WORK"

echo "[e2e] workspace=$WORK (ephemeral)"

# --- disposable Ed25519 keypair (test-only) ---
openssl genpkey -algorithm Ed25519 -out test_private.pem
openssl pkey -in test_private.pem -pubout -out test_public.pem
chmod 600 test_private.pem test_public.pem
PUB_BODY="$(grep -v 'PUBLIC KEY' test_public.pem | tr -d '\n')"

# Patch license_tools.py with test public key (workspace copy only)
python3 /Volumes/PortableSSD/soviez-project/soviez-sh/tests/integration/patch_test_pubkey.py \
  "$SRC_PY" test_public.pem license_tools.py

cat > Dockerfile <<EOF
FROM --platform=linux/amd64 ${IMG_BASE}
COPY license_tools.py /opt/soviez-erp/addons/local_license_guard/tools/license_tools.py
EOF

echo "[e2e] building disposable test image (does not modify production image)..."
docker build --platform linux/amd64 -t "$IMG_TAG" .

docker network create "$NET"
# Postgres on native arch for speed; ERP remains amd64 under qemu.
docker run -d --name "$PG" --network "$NET" \
  -e POSTGRES_USER=odoo -e POSTGRES_PASSWORD="$DB_PASS" -e POSTGRES_DB=postgres \
  postgres:16

echo "[e2e] waiting for postgres..."
ready=0
for i in $(seq 1 90); do
  if docker exec "$PG" pg_isready -U odoo >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done
if [[ "$ready" != "1" ]]; then
  echo "[e2e] postgres failed to become ready" >&2
  docker logs "$PG" 2>&1 | tail -40 >&2 || true
  exit 1
fi
docker exec "$PG" pg_isready -U odoo
echo "[e2e] postgres ready"
# Init DB with modules
echo "[e2e] initializing database (qemu/amd64 — may be slow)..."
docker run --rm --name "${WEB}-init" --network "$NET" --platform linux/amd64 \
  -e SOVIEZ_MIGRATION_SECRET="$MIG_SECRET" \
  "$IMG_TAG" \
  python3 soviez-bin -c soviez.conf \
    --db_host="$PG" --db_user=odoo --db_password="$DB_PASS" \
    -d "$DB_NAME" -i base,web,local_license_guard --without-demo=all --stop-after-init

# Start web (bind to existing DB)
docker run -d --name "$WEB" --network "$NET" --platform linux/amd64 \
  -e SOVIEZ_MIGRATION_SECRET="$MIG_SECRET" \
  -p 127.0.0.1::8069 \
  "$IMG_TAG" \
  python3 soviez-bin -c soviez.conf \
    --db_host="$PG" --db_user=odoo --db_password="$DB_PASS" \
    -d "$DB_NAME" --http-interface=0.0.0.0 --http-port=8069

sleep 3
if ! docker ps --format '{{.Names}}' | grep -qx "$WEB"; then
  echo "[e2e] web container exited early" >&2
  docker logs "$WEB" 2>&1 | tail -80 >&2 || true
  exit 1
fi

PORT="$(docker port "$WEB" 8069 | head -1 | awk -F: '{print $NF}')"
echo "[e2e] web on 127.0.0.1:${PORT}"

echo "[e2e] waiting for HTTP..."
http_ok=0
for i in $(seq 1 180); do
  if curl -fsS "http://127.0.0.1:${PORT}/web/login" -o /tmp/p8_login_pre.html 2>/dev/null; then
    http_ok=1
    break
  fi
  if ! docker ps --format '{{.Names}}' | grep -qx "$WEB"; then
    echo "[e2e] web died while waiting for HTTP" >&2
    docker logs "$WEB" 2>&1 | tail -100 >&2 || true
    exit 1
  fi
  sleep 2
done
if [[ "$http_ok" != "1" ]]; then
  echo "[e2e] HTTP never became ready" >&2
  docker logs "$WEB" 2>&1 | tail -100 >&2 || true
  exit 1
fi
echo "[e2e] HTTP ready"

# Fingerprint via official build_live_fingerprint (write to file — shell stdout is noisy)
docker exec -i -e SOVIEZ_MIGRATION_SECRET="$MIG_SECRET" "$WEB" \
  python3 soviez-bin shell -c soviez.conf \
  --db_host="$PG" --db_user=odoo --db_password="$DB_PASS" -d "$DB_NAME" --no-http <<'PY' >/tmp/p8_shell_fp.log 2>&1 || true
from odoo.addons.local_license_guard.tools import license_tools
try:
    fp = license_tools.build_live_fingerprint(env)
    open("/tmp/soviez_fp.txt", "w", encoding="utf-8").write(fp or "")
    open("/tmp/soviez_fp_err.txt", "w", encoding="utf-8").write("OK")
except Exception as e:
    open("/tmp/soviez_fp.txt", "w", encoding="utf-8").write("")
    open("/tmp/soviez_fp_err.txt", "w", encoding="utf-8").write("%s: %s" % (type(e).__name__, e))
PY

FP="$(docker exec "$WEB" cat /tmp/soviez_fp.txt 2>/dev/null || true)"
FP_ERR="$(docker exec "$WEB" cat /tmp/soviez_fp_err.txt 2>/dev/null || true)"
echo "[e2e] fingerprint obtained (redacted in evidence): len=${#FP} status=${FP_ERR}"
if [[ ! "$FP" =~ ^[0-9a-f]{64}::[0-9a-f-]{36}$ ]]; then
  echo "BAD_FINGERPRINT_FORMAT status=${FP_ERR}" >&2
  tail -40 /tmp/p8_shell_fp.log >&2 || true
  exit 1
fi

# Sign with disposable private key
KEY="$(python3 - <<PY
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from pathlib import Path
import base64
pem = Path("test_private.pem").read_bytes()
key = serialization.load_pem_private_key(pem, password=None)
fp = """${FP}""".encode()
sig = key.sign(fp)
print(base64.b64encode(sig).decode())
PY
)"

# Activate via official mixin (key via 0600 file staging — mirrors installer)
REMOTE="/tmp/.soviez_activate_e2e"
printf '%s' "$KEY" | docker exec -i "$WEB" bash -c "umask 077; cat > '$REMOTE' && chmod 600 '$REMOTE'"
docker exec -i -e SOVIEZ_MIGRATION_SECRET="$MIG_SECRET" "$WEB" python3 soviez-bin shell -c soviez.conf \
  --db_host="$PG" --db_user=odoo --db_password="$DB_PASS" -d "$DB_NAME" --no-http <<PY >/tmp/p8_shell_act.log 2>&1
from pathlib import Path
p = Path("$REMOTE")
key = p.read_text(encoding="utf-8").strip()
p.write_text("", encoding="utf-8")
p.unlink(missing_ok=True)
try:
    ok = env["soviez.license.mixin"].action_activate_soviez_license(key)
    icp = env["ir.config_parameter"].sudo()
    stored_fp = icp.get_param("soviez.license_fingerprint") or ""
    open("/tmp/soviez_act_result.txt","w",encoding="utf-8").write(
        "ACTIVATE_OK=%s\\nSTORED_FP_MATCH=%s\\nHAS_KEY=%s\\n" % (
            ok, stored_fp == """${FP}""", bool(icp.get_param("soviez.license_key"))
        )
    )
except Exception as e:
    open("/tmp/soviez_act_result.txt","w",encoding="utf-8").write("%s: %s\\n" % (type(e).__name__, e))
    raise
PY
ACT_RESULT="$(docker exec "$WEB" cat /tmp/soviez_act_result.txt)"
echo "[e2e] activation result: $ACT_RESULT"
echo "$ACT_RESULT" | grep -q 'ACTIVATE_OK=True' || { echo "ACTIVATION_FAILED" >&2; tail -40 /tmp/p8_shell_act.log >&2; exit 1; }

# Post-activation HTTP checks
sleep 2
LOGIN_CODE="$(curl -s -o /tmp/p8_login_post.html -w '%{http_code}' "http://127.0.0.1:${PORT}/web/login")"
ACT_CODE="$(curl -s -o /tmp/p8_act_post.html -w '%{http_code}' "http://127.0.0.1:${PORT}/web/activate_software" || true)"

# Deployment ledger check (best-effort)
docker exec -i -e SOVIEZ_MIGRATION_SECRET="$MIG_SECRET" "$WEB" python3 soviez-bin shell -c soviez.conf \
  --db_host="$PG" --db_user=odoo --db_password="$DB_PASS" -d "$DB_NAME" --no-http <<'PY' >/tmp/p8_shell_ledger.log 2>&1
from odoo.addons.local_license_guard.tools import license_tools
icp = env["ir.config_parameter"].sudo()
lines = []
for name in ("get_deployment_ledger", "read_deployment_ledger", "deployment_ledger_exists"):
    fn = getattr(license_tools, name, None)
    if callable(fn):
        try:
            lines.append("%s=%r" % (name, fn(icp) if name != "deployment_ledger_exists" else fn()))
        except TypeError:
            try:
                lines.append("%s=%r" % (name, fn(env)))
            except Exception as e:
                lines.append("%s=ERR:%s" % (name, type(e).__name__))
        except Exception as e:
            lines.append("%s=ERR:%s" % (name, type(e).__name__))
lines.append("LICENSE_STATUS=%s" % (icp.get_param("soviez.license_status") or icp.get_param("soviez.license_state") or ""))
open("/tmp/soviez_ledger.txt","w",encoding="utf-8").write("\n".join(lines))
PY
LEDGER="$(docker exec "$WEB" cat /tmp/soviez_ledger.txt 2>/dev/null || true)"

# Write sanitized evidence (NO keys, NO fingerprint full value, NO secrets)
{
  echo "# ERP ORM E2E (Phase 8)"
  echo
  echo "**Date:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "**Base image digest:** \`228cd4d4d3c88400b5fb0d7dd5092dc2328ed21e2646586244adbc49fda591fc\`"
  echo "**Method:** Disposable test Ed25519 keypair + patched \`license_tools.py\` overlay in ephemeral image tag \`$IMG_TAG\`."
  echo "**Production image/key:** unchanged."
  echo
  echo "## Results"
  echo
  echo "| Check | Result |"
  echo "|-------|--------|"
  echo "| Fingerprint format | PASS (64hex::uuid) |"
  echo "| Official \`action_activate_soviez_license\` | PASS |"
  echo "| Stored fingerprint matches live | see shell STORED_FP_MATCH |"
  echo "| HTTP /web/login | $LOGIN_CODE |"
  echo "| HTTP /web/activate_software | $ACT_CODE |"
  echo
  echo "## Ledger / status (sanitized)"
  echo '```'
  echo "$LEDGER" | sed -E 's/[A-Za-z0-9+/=]{40,}/<redacted>/g'
  echo '```'
  echo
  echo "## Cleanup"
  echo "Ephemeral workspace, containers, test image, and keys destroyed by trap."
} > "$RESULT_FILE"

echo "[e2e] evidence written to $RESULT_FILE"
echo "[e2e] LOGIN_HTTP=$LOGIN_CODE ACTIVATE_HTTP=$ACT_CODE"
echo ERP_ORM_E2E_COMPLETE
