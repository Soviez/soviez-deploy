#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/tests/helpers/s1_platform.sh"
s3_platform_source
export SOVIEZ_SH_ROOT="$ROOT" SOVIEZ_TEST_MODE=1
export SOVIEZ_S3_BASELINE_DIR
SOVIEZ_S3_BASELINE_DIR="$(mktemp -d)"
trap 'rm -rf "$SOVIEZ_S3_BASELINE_DIR"' EXIT

idx1="$(mktemp)"
idx2="$(mktemp)"
cat >"$idx1" <<'EOF'
{"records":[{"model":"ir.actions.server","id":1,"field":"code","content_sha256":"aaa","active":"t","name":"a"}]}
EOF
cat >"$idx2" <<'EOF'
{"records":[{"model":"ir.actions.server","id":1,"field":"code","content_sha256":"bbb","active":"t","name":"a"},{"model":"ir.actions.server","id":2,"field":"code","content_sha256":"ccc","active":"t","name":"new"}]}
EOF

# Refuse without reason
if SOVIEZ_S3_BASELINE_REASON= soviez_s3_baseline_save "$idx1" env 2>/dev/null; then
  echo "FAIL expected reason required" >&2; exit 1
fi

# Refuse with unresolved CRITICAL
if SOVIEZ_S3_BASELINE_REASON="init" SOVIEZ_S3_UNRESOLVED_CRITICAL=1 soviez_s3_baseline_save "$idx1" env 2>/dev/null; then
  echo "FAIL expected refuse critical" >&2; exit 1
fi

SOVIEZ_S3_BASELINE_REASON="clean-init" SOVIEZ_S3_UNRESOLVED_CRITICAL=0 soviez_s3_baseline_save "$idx1" env >/dev/null
diff_json="$(soviez_s3_baseline_diff "$idx1" env)"
echo "$diff_json" | grep -q '"status": "PASS"'

diff_json="$(soviez_s3_baseline_diff "$idx2" env)"
echo "$diff_json" | grep -q 'PASS_WITH_REVIEW'
echo "$diff_json" | grep -q '"changed"'
echo "$diff_json" | grep -q '"added"'

# Previous baseline preserved on update
SOVIEZ_S3_BASELINE_REASON="reviewed-update" SOVIEZ_S3_UNRESOLVED_CRITICAL=0 soviez_s3_baseline_save "$idx2" env >/dev/null
ls "$SOVIEZ_S3_BASELINE_DIR"/env.baseline.json.previous.* >/dev/null

echo PASS
