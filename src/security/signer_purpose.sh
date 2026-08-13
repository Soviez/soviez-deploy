# shellcheck shell=bash
# Phase 24 — signer purpose helpers (adapter; no new trust engine).

soviez_security_signer_purpose_assert() {
  local expected="$1" actual="$2"
  [[ "$expected" == "$actual" ]] && return 0
  soviez_security_die SECURITY_SIGNER_PURPOSE_MISMATCH "expected=$expected actual=$actual"
}

# Map ticket/artifact kinds to signer purposes used by offline_trust.
soviez_security_purpose_for_artifact() {
  local kind="$1"
  case "$kind" in
    release|update_manifest|installer) echo release ;;
    registry_pull|pull_ticket) echo registry_pull ;;
    offline_bundle|offline_update|bundle_manifest) echo bundle_manifest ;;
    authorization|offline_auth) echo authorization ;;
    migration_auth|migration_offline) echo migration_auth ;;
    *) echo "$kind" ;;
  esac
}
