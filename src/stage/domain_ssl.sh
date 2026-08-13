# shellcheck shell=bash
# Stage domain + SSL (mandatory trusted chain; self-signed rejected as final PASS).

soviez_stage_domain_validate_dns() {
  local domain="$1"
  local expected_ip="${2:-}"
  domain="$(soviez_stage_normalize_domain "$domain")" || soviez_stage_die DNS_VALIDATION_FAILED "Invalid domain syntax"

  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    # Fixture: allow domains under .test / .localhost or SOVIEZ_STAGE_DNS_OK=1
    if [[ "${SOVIEZ_STAGE_DNS_OK:-1}" == "1" ]]; then
      printf '{"ok":true,"domain":"%s","mode":"fixture"}\n' "$domain"
      return 0
    fi
    soviez_stage_die DNS_VALIDATION_FAILED "DNS fixture denied"
  fi

  local resolved
  resolved="$(getent ahostsv4 "$domain" 2>/dev/null | awk '{print $1; exit}' || true)"
  [[ -n "$resolved" ]] || soviez_stage_die DNS_VALIDATION_FAILED "A/AAAA resolution failed for $domain"
  if [[ -n "$expected_ip" && "$resolved" != "$expected_ip" ]]; then
    soviez_stage_die DNS_VALIDATION_FAILED "DNS $domain -> $resolved expected $expected_ip"
  fi
  printf '{"ok":true,"domain":"%s","resolved":"%s"}\n' "$domain" "$resolved"
}

soviez_stage_ssl_issue_and_validate() {
  local stage_id="$1"
  local domain="$2"
  local cfg
  cfg="$(soviez_stage_config_path "$stage_id")"
  mkdir -p "$cfg/ssl"
  local cert="$cfg/ssl/fullchain.pem"
  local key="$cfg/ssl/privkey.pem"
  local ca="${SOVIEZ_STAGE_TRUSTED_CA:-}"

  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    # Use local CA fixture — never accept self-signed as final PASS.
    if declare -F soviez_ssl_local_issue_cert >/dev/null 2>&1; then
      local issued
      issued="$(soviez_ssl_local_issue_cert "$domain")"
      local leaf keyf caf
      leaf="$(printf '%s\n' "$issued" | sed -n '1p')"
      keyf="$(printf '%s\n' "$issued" | sed -n '2p')"
      caf="$(printf '%s\n' "$issued" | sed -n '3p')"
      cp -f "$leaf" "$cert"
      cp -f "$keyf" "$key"
      ca="$caf"
    else
      # Minimal local CA + leaf for tests.
      local ca_dir="$SOVIEZ_ROOT/ssl-ca"
      mkdir -p "$ca_dir"
      if [[ ! -f "$ca_dir/ca.crt" ]]; then
        openssl req -x509 -newkey rsa:2048 -nodes -keyout "$ca_dir/ca.key" -out "$ca_dir/ca.crt" \
          -days 3650 -subj "/CN=Soviez Stage Test CA" >/dev/null 2>&1
      fi
      openssl req -newkey rsa:2048 -nodes -keyout "$key" -out "$cfg/ssl/req.csr" \
        -subj "/CN=$domain" >/dev/null 2>&1
      openssl x509 -req -in "$cfg/ssl/req.csr" -CA "$ca_dir/ca.crt" -CAkey "$ca_dir/ca.key" \
        -CAcreateserial -out "$cert" -days 825 >/dev/null 2>&1
      ca="$ca_dir/ca.crt"
    fi
    chmod 600 "$key"
    chmod 644 "$cert"
    soviez_ssl_validate_chain "$cert" "$ca"
    if [[ -z "$ca" ]]; then
      soviez_stage_die SSL_ISSUANCE_FAILED "Trusted CA required; self-signed not accepted"
    fi
    mkdir -p "$cfg/nginx"
    cat > "$cfg/nginx/${domain}.conf" <<EOF
# Stage nginx stub for ${domain}
server_name ${domain};
ssl_certificate ${cert};
ssl_certificate_key ${key};
EOF
    printf '%s\n' "${stage_id}" > "$cfg/nginx.owned"
    chmod 640 "$cfg/nginx.owned" 2>/dev/null || true
    printf '{"ok":true,"domain":"%s","cert":"%s","trusted":true}\n' "$domain" "$cert"
    return 0
  fi

  # Production: prefer Let's Encrypt path if available.
  if declare -F soviez_ssl_letsencrypt_issue >/dev/null 2>&1; then
    soviez_ssl_letsencrypt_issue "$domain" "$cert" "$key" \
      || soviez_stage_die SSL_ISSUANCE_FAILED "Let's Encrypt issuance failed"
  else
    soviez_stage_die SSL_ISSUANCE_FAILED "No SSL issuer available"
  fi
  chmod 600 "$key"
  soviez_ssl_validate_chain "$cert" ""
  printf '{"ok":true,"domain":"%s","cert":"%s"}\n' "$domain" "$cert"
}
