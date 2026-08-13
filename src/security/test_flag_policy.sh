# shellcheck shell=bash
# Phase 24 — test-flag quarantine / disposable-env detection.

soviez_security_cert_env() {
  export SOVIEZ_PHASE24_CERTIFICATION="${SOVIEZ_PHASE24_CERTIFICATION:-0}"
  export SOVIEZ_PHASE24_REQUIRE_STRICT_SIGNATURES="${SOVIEZ_PHASE24_REQUIRE_STRICT_SIGNATURES:-1}"
  export SOVIEZ_PHASE24_REQUIRE_SECRET_SCAN="${SOVIEZ_PHASE24_REQUIRE_SECRET_SCAN:-1}"
  export SOVIEZ_PHASE24_REQUIRE_REGISTRY_CLEAN="${SOVIEZ_PHASE24_REQUIRE_REGISTRY_CLEAN:-1}"
  export SOVIEZ_PHASE24_REQUIRE_REPLAY_TESTS="${SOVIEZ_PHASE24_REQUIRE_REPLAY_TESTS:-1}"
  # Certification defaults forbid test bypass; non-cert keeps 0 so disposable unit tests work.
  if [[ "${SOVIEZ_PHASE24_CERTIFICATION}" == "1" ]]; then
    export SOVIEZ_PHASE24_FORBID_TEST_BYPASS="${SOVIEZ_PHASE24_FORBID_TEST_BYPASS:-1}"
  else
    export SOVIEZ_PHASE24_FORBID_TEST_BYPASS="${SOVIEZ_PHASE24_FORBID_TEST_BYPASS:-0}"
  fi
  export SOVIEZ_PHASE24_FORBID_PRIVATE_KEYS_IN_DIST="${SOVIEZ_PHASE24_FORBID_PRIVATE_KEYS_IN_DIST:-1}"
  export SOVIEZ_PHASE24_FORBID_SERVICE_ROLE_IN_DIST="${SOVIEZ_PHASE24_FORBID_SERVICE_ROLE_IN_DIST:-1}"
  export SOVIEZ_PHASE24_FORBID_MATERIAL_SKIPS="${SOVIEZ_PHASE24_FORBID_MATERIAL_SKIPS:-1}"
  # Production default: signature verification is fail-closed.
  export SOVIEZ_UPDATE_STRICT_SIG="${SOVIEZ_UPDATE_STRICT_SIG:-1}"
}

soviez_security_is_disposable_env() {
  [[ "${SOVIEZ_DISPOSABLE_ENV:-0}" == "1" ]] && return 0
  [[ "${SOVIEZ_PHASE23_CERTIFICATION:-0}" == "1" ]] && return 0
  [[ "${SOVIEZ_PHASE24_CERTIFICATION:-0}" == "1" ]] && return 0
  local root="${SOVIEZ_ROOT:-}"
  [[ -n "$root" ]] || return 1
  case "$root" in
    /tmp/*|/private/tmp/*|/var/folders/*|*/.tmp/*|*/.phase23-cert-tmp/*|*/.phase24-cert-tmp/*)
      return 0 ;;
  esac
  case "$root" in
    *soviez-test*|*soviez-p1*|*soviez-p2*|*p15-final*|*p23-*|*p24-*)
      return 0 ;;
  esac
  return 1
}

soviez_security_is_production_target() {
  [[ "${SOVIEZ_SECURITY_FORCE_PRODUCTION:-0}" == "1" ]] && return 0
  # Explicit permanent customer marker
  [[ "${SOVIEZ_PRODUCTION_RUNTIME:-0}" == "1" ]] && return 0
  # Real docker update without test mode = production-like
  if [[ "${SOVIEZ_UPDATE_REAL_DOCKER:-0}" == "1" && "${SOVIEZ_TEST_MODE:-0}" != "1" ]]; then
    return 0
  fi
  return 1
}

# Test/cert bypass for fixture signatures & unsigned offline fixtures.
# Requires ALL: TEST_MODE + disposable env + not production target.
# Additionally denied when PHASE24_FORBID_TEST_BYPASS=1.
soviez_security_test_bypass_allowed() {
  if [[ "${SOVIEZ_PHASE24_FORBID_TEST_BYPASS:-0}" == "1" ]]; then
    return 1
  fi
  [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]] || return 1
  soviez_security_is_disposable_env || return 1
  if soviez_security_is_production_target; then
    return 1
  fi
  return 0
}

soviez_security_assert_test_bypass_or_die() {
  local why="${1:-test bypass}"
  if soviez_security_test_bypass_allowed; then
    return 0
  fi
  soviez_security_die SECURITY_TEST_BYPASS_DENIED "$why"
}

soviez_security_is_fake_signature() {
  local sig="${1:-}"
  case "$sig" in
    ok|valid|fixture|tampered|invalid|phase23-preverified|sig-final|sig|fixture-token)
      return 0 ;;
  esac
  # Short non-base64url fixture tokens
  if [[ ${#sig} -lt 16 && "$sig" != *"="* ]]; then
    case "$sig" in
      *[!A-Za-z0-9_-]*) ;;
      *)
        # still allow short hex digests? No — treat short alphanumeric as suspicious fixture
        [[ "$sig" =~ ^[A-Za-z0-9_-]+$ ]] && [[ ${#sig} -le 24 ]] && return 0
        ;;
    esac
  fi
  return 1
}
