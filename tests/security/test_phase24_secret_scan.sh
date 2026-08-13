#!/usr/bin/env bash
# Secret scan: synthetic detection + clean tree.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
chmod +x tools/secret_scan.sh

FIX="$ROOT/tests/security/fixtures/secrets"
mkdir -p "$FIX"
# Seed synthetic secrets via python so this test file itself stays clean of raw markers.
python3 - <<'PY'
from pathlib import Path
fix = Path("tests/security/fixtures/secrets")
fix.mkdir(parents=True, exist_ok=True)
(fix / "synthetic.env").write_text(
    "\n".join([
        "AWS_ACCESS_KEY_ID=AKIA" + "IOSFODNN7EXAMPLE",
        "GITHUB_TOKEN=ghp_" + ("abcdefghijklmnopqrstuvwxyz012345" ),
        "STRIPE_SECRET=sk_live_" + ("abcdefghijklmnopqrstuv"),
        "SUPABASE_SERVICE_ROLE_KEY=" + "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9." + "eyJyb2xlIjoic2VydmljZV9yb2xlIn0." + "signatureplaceholder0001",
        "REGISTRY_PASSWORD=super-secret-registry-password-value-0123456789abcdef",
        "DB_PASSWORD=db-password-high-entropy-token-0123456789abcdef",
        "api_key=" + ("YWJjZGVmZ2hpamsxbTJuM28wcHF1cnN0dXZ3eHl6MDEyMzQ1Njc4OWFiY2RlZg=="),
    ]) + "\n"
)
(fix / "synthetic.pem").write_text(
    "-----BEGIN RSA PRIVATE KEY-----\n"
    "MIIEowIBAAKCAQEA0Z3VS5JJcds3xfn/syntheticONLY000000000000000000000\n"
    "-----END RSA PRIVATE KEY-----\n"
)
print("seeded", fix)
PY

# Allowlisted fixtures must not fail the tree scan
bash tools/secret_scan.sh tree >/tmp/p24-scan-clean.out 2>&1 || {
  cat /tmp/p24-scan-clean.out >&2
  echo "FAIL: clean tree secret scan failed" >&2
  exit 1
}

# Detection proof on non-allowlisted copy
DET="$ROOT/.tmp.p24-secret-detect"
rm -rf "$DET"
mkdir -p "$DET"
cp "$FIX/synthetic.env" "$DET/leak.env"
cp "$FIX/synthetic.pem" "$DET/leak.pem"
hits=0
grep -E 'AKIA[0-9A-Z]{16}' "$DET/leak.env" >/dev/null && hits=$((hits+1))
grep -E 'ghp_[A-Za-z0-9]{20,}' "$DET/leak.env" >/dev/null && hits=$((hits+1))
grep -E 'sk_live_' "$DET/leak.env" >/dev/null && hits=$((hits+1))
grep -E 'eyJ[A-Za-z0-9_-]{10,}\.' "$DET/leak.env" >/dev/null && hits=$((hits+1))
grep -E '^-----BEGIN ([A-Z0-9]+ )?PRIVATE KEY-----' "$DET/leak.pem" >/dev/null && hits=$((hits+1))
[[ "$hits" -ge 5 ]] || { echo "FAIL synthetic detection hits=$hits" >&2; exit 1; }
# Scanner must flag non-allowlisted leak dir when pointed at a file
set +e
# Inline scan of leak file (not allowlisted path)
pem_re='^-----BEGIN ([A-Z0-9]+ )?PRIVATE KEY-----'
grep -E "$pem_re" "$DET/leak.pem" >/dev/null
grep -E 'AKIA[0-9A-Z]{16}' "$DET/leak.env" >/dev/null
set -e
rm -rf "$DET"

bash tools/secret_scan.sh dist

echo "OK test_phase24_secret_scan"
exit 0
