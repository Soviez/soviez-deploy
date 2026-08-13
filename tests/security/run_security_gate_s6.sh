#!/usr/bin/env bash
# Security Gate S6 — full security certification orchestration (glue over S1–S5).
# Prefer exact artifact 0.24.5.1-security-s5-corr1; do not assemble/bump VERSION unless product src changed.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH:-/usr/bin:/bin}"
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
export SOVIEZ_SH_ROOT="$ROOT"
export SOVIEZ_TEST_MODE=1
# shellcheck disable=SC1091
source "$ROOT/tests/helpers/s6_cert.sh"
# shellcheck disable=SC1091
source "$ROOT/tests/helpers/s1_platform.sh"

EXPECTED_VER="${S6_EXPECTED_VERSION}"
EXPECTED_SHA="${S6_EXPECTED_DIST_SHA256}"
fail=0

run() {
  local t="$1"
  echo "==> $t"
  if bash "$t"; then
    echo "OK $t"
  else
    echo "FAIL $t" >&2
    fail=1
  fi
}

# --- Assemble policy: skip when VERSION unchanged and dist already matches expected SHA ---
need_assemble=0
if [[ ! -f dist/soviez.sh ]]; then
  need_assemble=1
elif [[ ! -f VERSION ]]; then
  need_assemble=1
else
  actual_ver="$(tr -d '[:space:]' <VERSION)"
  actual_sha="$(s6_hash_file dist/soviez.sh)"
  if [[ "$actual_ver" == "$EXPECTED_VER" && "$actual_sha" == "$EXPECTED_SHA" ]]; then
    echo "OK certify exact artifact $EXPECTED_VER SHA256=${EXPECTED_SHA:0:16}… (skip assemble)"
  elif [[ "$actual_ver" == "$EXPECTED_VER" ]]; then
    # VERSION unchanged but SHA drift — only assemble if src product changed vs dist markers
    if [[ "${SOVIEZ_S6_FORCE_ASSEMBLE:-0}" == "1" ]]; then
      need_assemble=1
    else
      echo "WARN dist SHA drift without VERSION bump (actual=$actual_sha) — not assembling (S6 cert-only)" >&2
      echo "     Set SOVIEZ_S6_FORCE_ASSEMBLE=1 if src product intentionally changed." >&2
    fi
  else
    # VERSION changed → assemble expected
    need_assemble=1
  fi
fi

if [[ "$need_assemble" -eq 1 ]]; then
  echo "==> build/assemble.sh"
  bash build/assemble.sh
fi

bash -n dist/soviez.sh
command -v shellcheck >/dev/null 2>&1 && shellcheck -x tests/helpers/s6_cert.sh tests/security/s6/*.sh || true

# Matrix: execute by default for authoritative S6; light only when nested skip + light requested.
export SOVIEZ_S6_MATRIX_MODE="${SOVIEZ_S6_MATRIX_MODE:-execute}"
if [[ "${SOVIEZ_S6_SKIP_NESTED_REGRESSIONS:-0}" == "1" && "${SOVIEZ_S6_MATRIX_MODE}" == "execute" ]]; then
  # Avoid duplicating multi-hour guests already covered by S1–S5 in run_all; still execute unique S6 certs.
  export SOVIEZ_S6_MATRIX_MODE="${SOVIEZ_S6_MATRIX_LIGHT_WHEN_SKIP:-light}"
fi

for t in \
  tests/security/s6/test_s6_installer_parity.sh \
  tests/security/s6/test_s6_test_sec_matrix.sh \
  tests/security/s6/test_s6_real_pdf_odoo.sh \
  tests/security/s6/test_s6_full_restore_depth.sh \
  tests/security/s6/test_s6_telemetry_egress_audit.sh \
  tests/security/s6/test_s6_evidence_integrity.sh \
  tests/security/s6/test_s6_open_source_stack.sh \
  tests/security/s6/test_s6_adversarial_matrix.sh \
  tests/security/s6/test_s6_e2e_security_chain.sh
do
  [[ -f "$t" ]] || { echo "MISSING $t" >&2; fail=1; continue; }
  run "$t"
done

if [[ "${SOVIEZ_S6_SKIP_NESTED_REGRESSIONS:-0}" != "1" ]]; then
  [[ -x tests/security/run_security_gate_s5.sh ]] && SOVIEZ_S5_SKIP_NESTED_REGRESSIONS=1 run tests/security/run_security_gate_s5.sh
  [[ -x tests/security/run_s5_corr_apt_lock.sh ]] && SOVIEZ_CORR_SKIP_NESTED=1 run tests/security/run_s5_corr_apt_lock.sh
  [[ -x tests/security/run_security_gate_s4.sh ]] && SOVIEZ_S4_SKIP_NESTED_REGRESSIONS=1 run tests/security/run_security_gate_s4.sh
  [[ -x tests/security/run_security_gate_s3.sh ]] && SOVIEZ_S3_SKIP_NESTED_REGRESSIONS=1 run tests/security/run_security_gate_s3.sh
  [[ -x tests/security/run_security_gate_s2.sh ]] && SOVIEZ_S2_SKIP_NESTED_REGRESSIONS=1 run tests/security/run_security_gate_s2.sh
  [[ -x tests/security/run_security_gate_s1.sh ]] && run tests/security/run_security_gate_s1.sh
  [[ -x tests/security/run_phase24_security.sh ]] && run tests/security/run_phase24_security.sh
fi

if [[ $fail -ne 0 ]]; then
  echo "run_security_gate_s6: FAILED" >&2
  exit 1
fi
echo "run_security_gate_s6: PASS"
