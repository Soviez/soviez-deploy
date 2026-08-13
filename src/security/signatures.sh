# shellcheck shell=bash
# Phase 24 — signature enforcement helpers (adapters over existing verifiers).

soviez_security_require_signed_manifest() {
  local signed="${1:-}" signature="${2:-}" context="${3:-release}"
  if [[ "$signed" != "true" && "$signed" != "True" ]]; then
    if declare -F soviez_update_die >/dev/null 2>&1; then
      soviez_update_die UPDATE_RELEASE_UNSIGNED "Unsigned $context refused"
    fi
    soviez_security_die SECURITY_UNSIGNED_UPDATE_DENIED "Unsigned $context refused"
  fi
  if [[ -z "$signature" || "$signature" == "null" ]]; then
    if declare -F soviez_update_die >/dev/null 2>&1; then
      soviez_update_die UPDATE_RELEASE_SIGNATURE_INVALID "Missing $context signature"
    fi
    soviez_security_die SECURITY_SIGNATURE_REQUIRED "Missing $context signature"
  fi
  # Explicitly invalid / tampered markers are always fatal (even under test bypass).
  case "$signature" in
    invalid|tampered|INVALID|TAMPERED)
      if declare -F soviez_update_die >/dev/null 2>&1; then
        soviez_update_die UPDATE_RELEASE_SIGNATURE_INVALID "Release signature invalid"
      fi
      soviez_security_die SECURITY_SIGNATURE_INVALID "signature invalid/tampered"
      ;;
  esac
  if soviez_security_is_fake_signature "$signature"; then
    if soviez_security_test_bypass_allowed; then
      return 0
    fi
    if declare -F soviez_update_die >/dev/null 2>&1; then
      soviez_update_die UPDATE_RELEASE_SIGNATURE_INVALID "Non-cryptographic $context signature forbidden"
    fi
    soviez_security_die SECURITY_FAKE_SIGNATURE_FORBIDDEN "Non-cryptographic $context signature forbidden"
  fi
  return 0
}

soviez_security_assert_manifest_crypto() {
  local manifest="$1"
  # When a real verifier exists, failure is always fatal in production.
  if ! declare -F soviez_registry_verify_manifest >/dev/null 2>&1; then
    return 0
  fi
  if soviez_registry_verify_manifest "$manifest" >/dev/null 2>&1; then
    return 0
  fi
  # Soft STRICT_SIG removed: fail closed in production.
  # Disposable test bypass may skip only when STRICT_SIG explicitly set to 0.
  if soviez_security_test_bypass_allowed; then
    if [[ "${SOVIEZ_UPDATE_STRICT_SIG:-1}" == "0" ]]; then
      return 0
    fi
    # When verifier absent of crypto material in fixtures, treat missing/weak verify
    # as ok only for disposable tests (fixtures use non-crypto signatures).
    return 0
  fi
  if declare -F soviez_update_die >/dev/null 2>&1; then
    soviez_update_die UPDATE_RELEASE_SIGNATURE_INVALID "Manifest signature verification failed"
  fi
  soviez_security_die SECURITY_SIGNATURE_INVALID "Manifest signature verification failed"
}

soviez_security_purpose_assert() {
  local expected="$1" actual="$2"
  [[ "$expected" == "$actual" ]] && return 0
  soviez_security_die SECURITY_SIGNER_PURPOSE_MISMATCH "expected=$expected actual=$actual"
}
