# shellcheck shell=bash
# Phase 12 local certificate monitoring (no SaaS phone-home).

soviez_ssl_days_until_expiry() {
  local cert_path="$1"
  local end epoch_end now
  end="$(openssl x509 -in "$cert_path" -noout -enddate 2>/dev/null | sed 's/notAfter=//')"
  epoch_end="$(date -u -j -f "%b %d %T %Y %Z" "$end" +%s 2>/dev/null || date -u -d "$end" +%s 2>/dev/null || echo 0)"
  now="$(date -u +%s)"
  if [[ "$epoch_end" -eq 0 ]]; then
    printf '%s\n' "-9999"
    return 0
  fi
  printf '%s\n' "$(( (epoch_end - now) / 86400 ))"
}

soviez_ssl_check_permissions() {
  local cert_path="$1"
  local key_path="$2"
  local mode
  mode="$(stat -f '%Lp' "$key_path" 2>/dev/null || stat -c '%a' "$key_path" 2>/dev/null || echo 777)"
  # Reject world-readable private keys
  case "$mode" in
    *7|*6|*5|*4)
      # if last digit is 4-7, world readable/writable/executable
      local last="${mode: -1}"
      if [[ "$last" =~ [4567] ]]; then
        return 1
      fi
      ;;
  esac
  # Also reject if others bits set via octal compare when 3-digit
  if [[ ${#mode} -eq 3 ]]; then
    local others=$((10#${mode:2:1}))
    (( others == 0 )) || return 1
  fi
  return 0
}

soviez_ssl_check_key_match() {
  local cert_path="$1"
  local key_path="$2"
  local cert_mod key_mod
  cert_mod="$(openssl x509 -noout -modulus -in "$cert_path" 2>/dev/null | openssl md5)"
  key_mod="$(openssl rsa -noout -modulus -in "$key_path" 2>/dev/null | openssl md5)"
  [[ "$cert_mod" == "$key_mod" ]]
}

soviez_ssl_check_hostname() {
  local cert_path="$1"
  local domain="$2"
  # SAN or CN must match domain or wildcard scope
  local text
  text="$(openssl x509 -in "$cert_path" -noout -text 2>/dev/null || true)"
  if printf '%s' "$text" | grep -Eqi "DNS:${domain}([[:space:],]|$)|DNS:\\*\\.${domain#*.}"; then
    return 0
  fi
  local cn
  cn="$(openssl x509 -in "$cert_path" -noout -subject 2>/dev/null | sed -n 's/.*CN *= *\\([^,/]*\\).*/\\1/p')"
  [[ "$cn" == "$domain" ]]
}

soviez_ssl_monitor_env() {
  local env_id="$1"
  local rec cert key domain days state code="OK"
  rec="$(soviez_ssl_inventory_read "$env_id")"
  cert="$(soviez_json_get "$rec" certificate_path)"
  key="$(soviez_json_get "$rec" private_key_path)"
  domain="$(soviez_json_get "$rec" domain)"
  local chain
  chain="$(soviez_json_get "$rec" chain_path 2>/dev/null || true)"

  if [[ ! -f "$cert" ]]; then
    code="$SOVIEZ_SSL_CODE_CERTIFICATE_MISSING"
    state="needs_action"
  elif ! soviez_ssl_check_permissions "$cert" "$key"; then
    code="$SOVIEZ_SSL_CODE_CERTIFICATE_PERMISSION_INVALID"
    state="needs_action"
  elif ! soviez_ssl_check_key_match "$cert" "$key"; then
    code="$SOVIEZ_SSL_CODE_CERTIFICATE_KEY_MISMATCH"
    state="needs_action"
  elif ! soviez_ssl_check_hostname "$cert" "$domain"; then
    code="$SOVIEZ_SSL_CODE_CERTIFICATE_HOSTNAME_MISMATCH"
    state="needs_action"
  else
    # Chain / self-signed
    if [[ -n "$chain" && -f "$chain" ]]; then
      if ! openssl verify -CAfile "$chain" "$cert" >/dev/null 2>&1; then
        code="$SOVIEZ_SSL_CODE_CERTIFICATE_CHAIN_INVALID"
        state="needs_action"
      fi
    else
      if ! soviez_ssl_validate_chain "$cert" "${chain:-}" 2>/dev/null; then
        # Map self-signed specifically
        local issuer subject
        issuer="$(openssl x509 -in "$cert" -noout -issuer 2>/dev/null | tr -d ' ' | sed 's/issuer=//')"
        subject="$(openssl x509 -in "$cert" -noout -subject 2>/dev/null | tr -d ' ' | sed 's/subject=//')"
        if [[ "$issuer" == "$subject" ]]; then
          code="$SOVIEZ_SSL_CODE_SELF_SIGNED_NOT_ALLOWED"
        else
          code="$SOVIEZ_SSL_CODE_CERTIFICATE_UNTRUSTED"
        fi
        state="needs_action"
      fi
    fi
  fi

  if [[ "$code" == "OK" ]]; then
    days="$(soviez_ssl_days_until_expiry "$cert")"
    if (( days < 0 )); then
      code="$SOVIEZ_SSL_CODE_CERTIFICATE_EXPIRED"
      state="certificate_expired"
    else
      local lead
      lead="$(soviez_json_get "$rec" renewal_lead_days)"
      [[ -n "$lead" ]] || lead=30
      if (( days <= lead )); then
        state="renewal_window"
      else
        state="healthy"
      fi
      # Warning thresholds (local-first)
      local w
      for w in $SOVIEZ_SSL_WARNING_DAYS; do
        if (( days == w )); then
          :
        fi
      done
    fi
  fi

  # Detect external replacement via digest mismatch
  if [[ "$code" == "OK" || "$state" == "renewal_window" || "$state" == "healthy" ]]; then
    local expected actual
    expected="$(soviez_json_get "$rec" current_certificate_digest)"
    actual="$(openssl x509 -in "$cert" -noout -fingerprint -sha256 2>/dev/null | sed 's/.*=//' | tr -d ':')"
    if [[ -n "$expected" && -n "$actual" && "$expected" != "$actual" ]]; then
      code="CERTIFICATE_EXTERNALLY_REPLACED"
      state="needs_action"
    fi
  fi

  printf '%s\n' "$state"
  printf '%s\n' "$code"
  printf '%s\n' "${days:--}"
}

soviez_ssl_monitor_apply() {
  local env_id="$1"
  local out state code days
  out="$(soviez_ssl_monitor_env "$env_id")"
  state="$(printf '%s\n' "$out" | sed -n '1p')"
  code="$(printf '%s\n' "$out" | sed -n '2p')"
  days="$(printf '%s\n' "$out" | sed -n '3p')"
  local patch
  if [[ "$code" == "OK" ]]; then
    patch="$(python3 - <<PY
import json
print(json.dumps({
  "lifecycle_state": "$state",
  "hostname_verification": "pass",
  "chain_verification": "pass",
  "last_failure_code": None,
  "days_remaining": int("$days") if "$days".lstrip("-").isdigit() or "$days".isdigit() else None
}))
PY
)"
  else
    patch="$(python3 - <<PY
import json
print(json.dumps({
  "lifecycle_state": "$state",
  "last_failure_code": "$code",
  "days_remaining": None
}))
PY
)"
  fi
  soviez_ssl_inventory_patch "$env_id" "$patch"
  printf '%s %s days=%s\n' "$state" "$code" "$days"
}
