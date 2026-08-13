# shellcheck shell=bash

soviez_manifest_verify() {
  local manifest_json="$1"
  local expected_digest="$2"
  local digest
  digest="$(soviez_json_get "$manifest_json" "digest")"
  if [[ "$digest" != "$expected_digest" ]]; then
    soviez_die "$SOVIEZ_ERR_API" "Manifest digest mismatch"
  fi
  local sig
  sig="$(soviez_json_get "$manifest_json" "signature" 2>/dev/null || true)"
  if [[ -z "$sig" && "${SOVIEZ_TEST_MODE:-0}" != "1" ]]; then
    soviez_die "$SOVIEZ_ERR_API" "Manifest missing signature"
  fi
  soviez_log_info "Manifest verified digest=$digest"
}
