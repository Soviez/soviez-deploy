#!/usr/bin/env bash
# Phase 23: archive attack matrix + multi-tenant isolation + no-network apply
set -euo pipefail
set +o pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
bash build/assemble.sh >/dev/null
export SOVIEZ_OPENSSL="${SOVIEZ_OPENSSL:-/opt/homebrew/bin/openssl}"

source src/offline_trust/keys.sh
source src/offline_bundle/codes.sh
source src/offline_bundle/paths.sh
source src/offline_bundle/entitlement.sh
source src/offline_bundle/package.sh
source src/offline_bundle/replay.sh
source src/offline_bundle/import.sh
source src/offline_bundle/cert_gates.sh
source src/offline_update/apply.sh

soviez_json_get() {
  local json="$1" key="$2"
  SOVIEZ_J="$json" SOVIEZ_K="$key" python3 - <<'PY'
import json,os
d=json.loads(os.environ["SOVIEZ_J"]); k=os.environ["SOVIEZ_K"]; v=d
for p in k.split("."):
  if isinstance(v,dict) and p in v: v=v[p]
  else: print(""); raise SystemExit(0)
print(v if not isinstance(v,(dict,list)) else json.dumps(v))
PY
}
soviez_paths_init() { :; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/p23-int.XXXXXX")"
export SOVIEZ_ROOT="$TMP/root" SOVIEZ_TEST_MODE=1
export SOVIEZ_PHASE23_CERTIFICATION=1
export SOVIEZ_PHASE23_REQUIRE_REAL_ED25519=1
export SOVIEZ_PHASE23_FORBID_FAKE_SIGNATURES=1
export SOVIEZ_PHASE23_REQUIRE_NO_NETWORK_APPLY=1
export SOVIEZ_OFFLINE_TRUST_DIR="$TMP/trust"
export SOVIEZ_OFFLINE_BUNDLE_ROOT="$TMP/bundles"

echo "== multi-tenant: two licenses/devices =="
d1="sha256:$(printf a | shasum -a 256 | awk '{print $1}')"
d2="sha256:$(printf b | shasum -a 256 | awk '{print $1}')"
a1="$(soviez_offline_bundle_issue_local bun-t1 lic-1 env-1 fp-1 "$d1" "$d1")"
a2="$(soviez_offline_bundle_issue_local bun-t2 lic-2 env-2 fp-2 "$d2" "$d2")"
soviez_offline_bundle_import "$a1" lic-1 env-1 fp-1 "$d1" >/dev/null
set +e
SOVIEZ_OFFLINE_SOFT_DIE=1 soviez_offline_bundle_import "$a1" lic-2 env-2 fp-2 "$d1" >/dev/null 2>&1
rc=$?
unset SOVIEZ_OFFLINE_SOFT_DIE
set -e
[[ $rc -ne 0 ]]

echo "== path traversal denied =="
python3 - <<PY
import tarfile, io
p="$TMP/trav.tar"
with tarfile.open(p,"w") as t:
  ti=tarfile.TarInfo(name="../escape.txt")
  data=b"evil"
  ti.size=len(data)
  t.addfile(ti, io.BytesIO(data))
PY
set +e
SOVIEZ_OFFLINE_SOFT_DIE=1 soviez_offline_bundle_archive_security_scan "$TMP/trav.tar" >/dev/null 2>&1
rc=$?
unset SOVIEZ_OFFLINE_SOFT_DIE
set -e
[[ $rc -ne 0 ]]

echo "== air-gapped apply (proxies deny network) =="
export SOVIEZ_LICENSE_ID=lic-1 SOVIEZ_ENVIRONMENT_ID=env-1 SOVIEZ_DEVICE_FINGERPRINT=fp-1
export SOVIEZ_OFFLINE_APPLY_YES=1
a3="$(soviez_offline_bundle_issue_local bun-t3 lic-1 env-1 fp-1 "$d1" "$d1")"
soviez_phase23_assert_no_network_hooks
apply_out="$(soviez_offline_update_apply "$a3")"
printf '%s\n' "$apply_out" | grep -q 'RESULT RECEIPT — SIGNED'
[[ "${http_proxy:-}" == *127.0.0.1* ]]

echo "== secret scan in bundle =="
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/p23-scan.XXXXXX")
zstd -q -dc "$a3" | tar -xf - -C "$tmpdir"
! grep -R 'BEGIN PRIVATE\|BEGIN RSA\|"auths"' "$tmpdir" >/dev/null 2>&1
rm -rf "$tmpdir"

echo "OK test_phase23_offline_bundle_integration"
rm -rf "$TMP"
exit 0
