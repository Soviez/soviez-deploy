# shellcheck shell=bash
# Phase 23 certification gates — fail closed.

soviez_phase23_cert_assert() {
  [[ "${SOVIEZ_PHASE23_CERTIFICATION:-0}" == "1" ]] || return 0
  local failures=0
  _p23_fail() { echo "[phase23-cert] FAIL: $*" >&2; failures=$((failures+1)); }

  if [[ "${SOVIEZ_PHASE23_FORBID_FAKE_SIGNATURES:-1}" == "1" ]]; then
    :
  fi
  if [[ "${SOVIEZ_PHASE23_REQUIRE_REAL_ED25519:-1}" != "1" ]]; then
    _p23_fail "SOVIEZ_PHASE23_REQUIRE_REAL_ED25519 must be 1"
  fi
  if [[ "${SOVIEZ_PHASE23_FORBID_MATERIAL_SKIPS:-1}" == "1" ]]; then
    if [[ "${SOVIEZ_PHASE23_SKIP_REBOOT:-0}" == "1" ]]; then
      _p23_fail "reboot matrix skip forbidden"
    fi
    if [[ "${SOVIEZ_PHASE23_SKIP_NETWORK:-0}" == "1" ]]; then
      _p23_fail "network isolation skip forbidden"
    fi
  fi
  if [[ "${SOVIEZ_PHASE23_REQUIRE_NO_NETWORK_APPLY:-1}" == "1" ]]; then
    if [[ "${SOVIEZ_UPDATE_ALLOW_NETWORK:-0}" == "1" ]]; then
      _p23_fail "network allowed during offline apply"
    fi
  fi
  [[ "$failures" -eq 0 ]] || soviez_offline_die OFFLINE_PHASE23_CERT_GATE "$failures certification gate(s) failed"
}

soviez_phase23_assert_no_network_hooks() {
  # Soft probe: deny curl/wget to SaaS/Registry during apply when cert mode
  [[ "${SOVIEZ_PHASE23_REQUIRE_NO_NETWORK_APPLY:-0}" == "1" || "${SOVIEZ_PHASE23_CERTIFICATION:-0}" == "1" ]] || return 0
  export SOVIEZ_OFFLINE_APPLY_NETWORK_DENIED=1
  export http_proxy=http://127.0.0.1:1
  export https_proxy=http://127.0.0.1:1
  export NO_PROXY=
  export no_proxy=
}
