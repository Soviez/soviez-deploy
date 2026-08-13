#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
bash build/assemble.sh >/dev/null
# shellcheck source=/dev/null
source dist/soviez.sh

TMP="$(mktemp -d "${TMPDIR:-/tmp}/p24-key.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
export SOVIEZ_ROOT="$TMP/root" SOVIEZ_TEST_MODE=1 SOVIEZ_DISPOSABLE_ENV=1
soviez_paths_init 2>/dev/null || true

# Generate disposable ed25519 keypair if openssl available
if command -v openssl >/dev/null 2>&1; then
  openssl genpkey -algorithm Ed25519 -out "$TMP/priv.pem" 2>/dev/null || openssl genrsa -out "$TMP/priv.pem" 2048 >/dev/null 2>&1
  openssl pkey -in "$TMP/priv.pem" -pubout -out "$TMP/pub.pem" 2>/dev/null
  chmod 600 "$TMP/priv.pem"
  fp="$(soviez_security_pubkey_fingerprint "$TMP/pub.pem")"
  [[ "$fp" == sha256:* ]]
  soviez_security_assert_private_key_perms "$TMP/priv.pem"
  chmod 644 "$TMP/priv.pem"
  set +e
  (soviez_security_assert_private_key_perms "$TMP/priv.pem") >/dev/null 2>&1
  rc=$?
  set -e
  [[ $rc -ne 0 ]]
fi

# Secret write produces fingerprint sidecar
export SOVIEZ_SECRETS_DIR="$TMP/secrets"
mkdir -p "$SOVIEZ_SECRETS_DIR"
soviez_tenant_secret_write "demo_token" "not-a-real-secret-value-for-hygiene"
[[ -f "$SOVIEZ_SECRETS_DIR/demo_token.sha256" ]]
chmod 600 "$SOVIEZ_SECRETS_DIR/demo_token"

# Dist must not contain PEM private signing keys (line-anchored header)
if grep -E '^-----BEGIN ([A-Z0-9]+ )?PRIVATE KEY-----' dist/soviez.sh >/dev/null 2>&1; then
  echo "FAIL private key PEM in dist" >&2
  exit 1
fi

echo "OK test_phase24_key_hygiene"
exit 0
