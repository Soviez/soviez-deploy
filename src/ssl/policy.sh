# shellcheck shell=bash
# Phase 12 Production/Stage SSL policy (owner-approved defaults).

# Defaults (binding owner decisions)
SOVIEZ_SSL_DEFAULT_RENEWAL_MODE="${SOVIEZ_SSL_DEFAULT_RENEWAL_MODE:-automatic}"
SOVIEZ_SSL_DEFAULT_RENEWAL_LEAD_DAYS="${SOVIEZ_SSL_DEFAULT_RENEWAL_LEAD_DAYS:-30}"
SOVIEZ_SSL_DEFAULT_ACME_PROVIDER="${SOVIEZ_SSL_DEFAULT_ACME_PROVIDER:-letsencrypt}"
SOVIEZ_SSL_WARNING_DAYS="${SOVIEZ_SSL_WARNING_DAYS:-30 14 7 3 1}"
SOVIEZ_SSL_ALLOW_PRIVATE_CA="${SOVIEZ_SSL_ALLOW_PRIVATE_CA:-0}"
SOVIEZ_SSL_ALLOW_WILDCARD="${SOVIEZ_SSL_ALLOW_WILDCARD:-0}"

soviez_ssl_policy_normalize_mode() {
  local mode="${1:-automatic}"
  case "$mode" in
    automatic|notify_only|manual) printf '%s\n' "$mode" ;;
    *) soviez_ssl_die "$SOVIEZ_SSL_CODE_RENEWAL_DISABLED" "Invalid renewal mode: $mode" ;;
  esac
}

soviez_ssl_policy_assert_ca() {
  local mode="$1" # public|private_ca|self_signed
  case "$mode" in
    public) return 0 ;;
    private_ca)
      if [[ "${SOVIEZ_SSL_ALLOW_PRIVATE_CA}" != "1" ]]; then
        soviez_ssl_die "$SOVIEZ_SSL_CODE_PRIVATE_CA_NOT_APPROVED" \
          "Private CA requires explicit enterprise policy (SOVIEZ_SSL_ALLOW_PRIVATE_CA=1)"
      fi
      return 0
      ;;
    self_signed)
      soviez_ssl_die "$SOVIEZ_SSL_CODE_SELF_SIGNED_NOT_ALLOWED" "Self-signed certificates are not accepted as final PASS"
      ;;
    *)
      soviez_ssl_die "$SOVIEZ_SSL_CODE_CERTIFICATE_UNTRUSTED" "Unknown certificate mode: $mode"
      ;;
  esac
}

soviez_ssl_policy_assert_wildcard() {
  local want_wildcard="$1"
  if [[ "$want_wildcard" == "1" || "$want_wildcard" == "true" ]]; then
    if [[ "${SOVIEZ_SSL_ALLOW_WILDCARD}" != "1" ]]; then
      soviez_ssl_die "$SOVIEZ_SSL_CODE_WILDCARD_NOT_ALLOWED" "Wildcard requires explicit operator selection"
    fi
  fi
}

# Production readiness: never "ready" until trusted HTTPS passes.
soviez_ssl_policy_production_ready() {
  local lifecycle_state="$1"
  [[ "$lifecycle_state" == "ready" || "$lifecycle_state" == "healthy" ]]
}

soviez_ssl_policy_renewal_priority() {
  local env_type="$1"
  case "$env_type" in
    production|Production) printf '10\n' ;;
    stage|Stage) printf '5\n' ;;
    *) printf '1\n' ;;
  esac
}
