#!/usr/bin/env bash
# Sign a platform-release manifest with staging Ed25519 private key (release-control only).
# Never runs on customer hosts. Private key path via SOVIEZ_PLATFORM_STAGING_PRIVKEY.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="${1:-}"
PRIV="${SOVIEZ_PLATFORM_STAGING_PRIVKEY:-/Volumes/PortableSSD/soviez-project/.secrets/staging-platform-keys/soviez-platform-staging-2026-08.key}"
[[ -f "$MANIFEST" ]] || { echo "usage: $0 manifest.json" >&2; exit 1; }
[[ -f "$PRIV" ]] || { echo "missing private key: $PRIV" >&2; exit 1; }
# shellcheck source=/dev/null
source "$ROOT/src/platform/trust.sh"
payload="$(soviez_platform_manifest_canonical_payload "$MANIFEST")"
sig="$(soviez_platform_sign_payload "$payload" "$PRIV")" || { echo "sign failed" >&2; exit 1; }
SOVIEZ_M="$MANIFEST" SOVIEZ_S="$sig" python3 - <<'PY'
import json, os, datetime
p=os.environ["SOVIEZ_M"]
m=json.load(open(p,encoding="utf-8"))
m["signed"]=True
m["signature_algorithm"]="ed25519"
m["signature_b64url"]=os.environ["SOVIEZ_S"]
m["signature"]=os.environ["SOVIEZ_S"]
m["signed_at"]=datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
open(p,"w",encoding="utf-8").write(json.dumps(m, indent=2, sort_keys=True)+"\n")
print("signed", p)
print("signature_b64url", os.environ["SOVIEZ_S"][:24]+"...")
PY
