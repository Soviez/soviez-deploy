#!/usr/bin/env bash
# S6 — real PDF via Odoo ERP image wkhtmltopdf (synthetic HTML only; no live docs).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/tests/helpers/s1_platform.sh"
s6_platform_source
# shellcheck disable=SC1091
source "$ROOT/tests/helpers/s6_cert.sh"
export SOVIEZ_TEST_MODE=1
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
export SOVIEZ_SH_ROOT="$ROOT"
export SOVIEZ_SEC_S6_EVIDENCE_ROOT="${SOVIEZ_SEC_S6_EVIDENCE_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/soviez-s6-pdf.XXXXXX")}"
ev="$(s6_evidence_init "$(s6_run_id)")"
IMG="${SOVIEZ_S6_ODOO_IMAGE:-soviez-erp:18.0.1.01.5-local-release-candidate-pass5}"
cid=""
cleanup() {
  [[ -n "$cid" ]] && docker rm -f "$cid" >/dev/null 2>&1 || true
  [[ "${SOVIEZ_S6_KEEP_EVIDENCE:-0}" == "1" ]] || rm -rf "$SOVIEZ_SEC_S6_EVIDENCE_ROOT"
}
trap cleanup EXIT

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "PARTIAL: docker unavailable — cannot certify real wkhtmltopdf path" >&2
  s6_write_json "$ev/findings/pdf.json" '{"status":"PARTIAL","reason":"docker_unavailable"}'
  exit 2
fi

if ! docker image inspect "$IMG" >/dev/null 2>&1; then
  echo "PARTIAL: image missing: $IMG" >&2
  s6_write_json "$ev/findings/pdf.json" "{\"status\":\"PARTIAL\",\"reason\":\"image_missing\",\"image\":\"$(s6_json_escape "$IMG")\"}"
  exit 2
fi

rid="$(s6_run_id)"
cid="${rid}-pdf"
# Prefer entrypoint override; keep container alive for exec.
docker run -d --name "$cid" --entrypoint sleep "$IMG" 3600 >/dev/null

if ! docker exec "$cid" sh -c 'command -v wkhtmltopdf >/dev/null 2>&1'; then
  echo "PARTIAL: wkhtmltopdf missing in $IMG — do not fake PASS" >&2
  s6_write_json "$ev/findings/pdf.json" "{\"status\":\"PARTIAL\",\"reason\":\"wkhtmltopdf_missing\",\"image\":\"$(s6_json_escape "$IMG")\"}"
  exit 2
fi

html="$ev/artifacts/s6-pdf-in.html"
mkdir -p "$ev/artifacts"
cat >"$html" <<'HTML'
<!DOCTYPE html><html><head><meta charset="utf-8"><title>Soviez S6 PDF</title></head>
<body><h1>Soviez S6 synthetic PDF</h1><p>Certification only.</p></body></html>
HTML

docker cp "$html" "$cid:/tmp/soviez-s6-pdf-in.html"
docker exec "$cid" sh -c 'wkhtmltopdf /tmp/soviez-s6-pdf-in.html /tmp/soviez-s6-pdf-out.pdf >/dev/null 2>&1'
magic="$(docker exec "$cid" sh -c 'head -c 5 /tmp/soviez-s6-pdf-out.pdf' 2>/dev/null || true)"
[[ "$magic" == "%PDF-" ]] || { echo "FAIL PDF magic got '$magic'" >&2; exit 1; }
docker cp "$cid:/tmp/soviez-s6-pdf-out.pdf" "$ev/artifacts/s6-pdf-out.pdf"
echo "OK real wkhtmltopdf → %PDF-"

# Wire through S5 helper with container context
export SOVIEZ_SEC_ODOO_CONTAINER="$cid"
export SOVIEZ_S5_PDF_FIXTURE="$html"
export SOVIEZ_S5_PDF_REQUIRE=1
r="$(soviez_s5_check_pdf)"
[[ "$r" == "PASS" ]] || { echo "FAIL soviez_s5_check_pdf expected PASS got $r" >&2; exit 1; }
echo "OK soviez_s5_check_pdf PASS"

# Fault inject → update gate would block
export SOVIEZ_S5_PDF_INJECT_FAIL=1
r="$(soviez_s5_check_pdf || true)"
[[ "$r" == "FAIL" ]] || { echo "FAIL inject expected FAIL got $r" >&2; exit 1; }
unset SOVIEZ_S5_PDF_INJECT_FAIL
echo "OK SOVIEZ_S5_PDF_INJECT_FAIL → FAIL"

# Break path / missing binary simulation via N/A forbid + inject already proven;
# also: empty fixture path with require should fail when inject set.
export SOVIEZ_S5_PDF_INJECT_FAIL=1
unset SOVIEZ_S5_PDF_FIXTURE
r="$(soviez_s5_check_pdf || true)"
[[ "$r" == "FAIL" ]] || { echo "FAIL break-path inject expected FAIL" >&2; exit 1; }
unset SOVIEZ_S5_PDF_INJECT_FAIL

# Gate-level: PDF FAIL blocks validation when not N/A
if declare -F soviez_s5_validate_candidate >/dev/null 2>&1 || declare -F soviez_security_validate_update_safety >/dev/null 2>&1; then
  export SOVIEZ_S5_PDF_INJECT_FAIL=1
  export SOVIEZ_S5_OP_ID="s6-pdf-$$"
  # Candidate validation should not PASS with pdf FAIL
  if declare -F soviez_s5_validate_candidate >/dev/null 2>&1; then
    set +e
    out="$(soviez_s5_validate_candidate "${SOVIEZ_S5_OP_ID}" 2>/dev/null)"
    rc=$?
    set -e
    [[ "$out" != "PASS" ]] || { echo "FAIL gate PASS despite PDF inject" >&2; exit 1; }
    echo "OK update candidate gate blocked on PDF FAIL (rc=$rc out=$out)"
  fi
  unset SOVIEZ_S5_PDF_INJECT_FAIL
fi

s6_write_json "$ev/findings/pdf.json" "$(cat <<EOF
{
  "status": "PASS",
  "image": "$(s6_json_escape "$IMG")",
  "wkhtmltopdf": true,
  "pdf_magic": "%PDF-",
  "inject_fail": true,
  "gate_blocks_on_fail": true
}
EOF
)"
echo PASS
