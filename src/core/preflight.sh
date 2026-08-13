# shellcheck shell=bash

soviez_preflight_run() {
  soviez_log_info "Running preflight checks"
  soviez_require_cmd bash
  soviez_require_cmd curl
  soviez_require_cmd openssl
  soviez_require_cmd python3

  if [[ "${SOVIEZ_TEST_MODE:-0}" != "1" ]]; then
    if [[ "$(id -u)" -ne 0 ]]; then
      soviez_die "$SOVIEZ_ERR_PREFLIGHT" "Soviez installer must run as root outside test mode"
    fi
    soviez_require_cmd docker
    soviez_require_cmd systemctl
  fi

  if ! openssl list -public-key-algorithms 2>/dev/null | grep -qi ed25519; then
    soviez_log_warn "OpenSSL Ed25519 support not detected; device auth may fail"
  fi

  soviez_log_info "Preflight checks passed"
}
