# shellcheck shell=bash
# Phase 18 — real ACME issuance against local Pebble (disposable fixture).

soviez_migration_tls_pebble_network() {
  printf '%s\n' "${SOVIEZ_MIG_ACME_DOCKER_NETWORK:-soviez-p18-acme}"
}

soviez_migration_tls_pebble_ensure() {
  local net ctn
  net="$(soviez_migration_tls_pebble_network)"
  ctn="${SOVIEZ_MIG_ACME_PEBBLE_CTN:-soviez-p18-pebble}"
  docker network inspect "$net" >/dev/null 2>&1 || docker network create "$net" >/dev/null
  if ! docker inspect "$ctn" >/dev/null 2>&1; then
    # Image entrypoint is /app (pebble binary). Do not prefix with "pebble".
    # PEBBLE_VA_ALWAYS_VALID: ACME order/CSR/issue/chain are real; VA short-circuited.
    docker run -d --name "$ctn" --network "$net" --network-alias pebble \
      -e PEBBLE_VA_ALWAYS_VALID=1 \
      -e PEBBLE_VA_NOSLEEP=1 \
      ghcr.io/letsencrypt/pebble:2.7.0 >/dev/null \
      || soviez_migration_die MIGRATION_ACME_ORDER_FAILED "Failed to start Pebble"
  fi
  local i
  for i in $(seq 1 40); do
    if docker run --rm --network "$net" curlimages/curl:8.5.0 \
      -sk https://pebble:14000/dir >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.5
  done
  soviez_migration_die MIGRATION_ACME_ORDER_FAILED "Pebble directory unavailable"
}

soviez_migration_tls_pebble_issue() {
  local pair_id="$1" fqdn="$2"
  local sec_dir net ctn vol
  soviez_migration_paths_init
  sec_dir="$(soviez_migration_tls_secrets_dir "$pair_id" "$fqdn")"
  mkdir -p "$sec_dir"
  chmod 700 "$sec_dir"
  net="$(soviez_migration_tls_pebble_network)"
  ctn="${SOVIEZ_MIG_ACME_PEBBLE_CTN:-soviez-p18-pebble}"
  soviez_migration_tls_pebble_ensure

  vol="soviez-p18-lego-$$"
  docker volume create "$vol" >/dev/null

  # Real ACME client (lego) against Pebble — TLS verify disabled only for disposable Pebble minica.
  if ! docker run --rm --network "$net" \
      -v "$vol:/data" \
      --entrypoint /lego \
      goacme/lego:v4.22.2 \
      --server https://pebble:14000/dir --accept-tos \
      --email soviez-p18-fixture@example.test \
      --http --http.port :5002 \
      --path /data \
      --domains "$fqdn" \
      --tls-skip-verify \
      run >"$sec_dir/lego.out" 2>"$sec_dir/lego.err"; then
    docker volume rm "$vol" >/dev/null 2>&1 || true
    soviez_migration_die MIGRATION_ACME_ORDER_FAILED "lego/Pebble issuance failed"
  fi

  # Extract certs from volume onto host via docker cp
  local hlp="soviez-p18-lego-hlp-$$"
  docker create --name "$hlp" -v "$vol:/data" alpine:3.20 true >/dev/null
  mkdir -p "$sec_dir/extract"
  docker cp "$hlp:/data/certificates/." "$sec_dir/extract/" 2>/dev/null || true
  docker rm "$hlp" >/dev/null
  docker volume rm "$vol" >/dev/null 2>&1 || true

  local cert_file key_file issuer_file
  cert_file="$(find "$sec_dir/extract" -name '*.crt' ! -name '*.issuer.crt' 2>/dev/null | head -1)"
  key_file="$(find "$sec_dir/extract" -name '*.key' 2>/dev/null | head -1)"
  issuer_file="$(find "$sec_dir/extract" -name '*.issuer.crt' 2>/dev/null | head -1)"
  [[ -n "$cert_file" && -f "$cert_file" && -n "$key_file" && -f "$key_file" ]] \
    || soviez_migration_die MIGRATION_TLS_ISSUANCE_FAILED "Pebble certificates missing after lego"

  cp "$key_file" "$sec_dir/privkey.pem"
  cp "$cert_file" "$sec_dir/cert.pem"
  if [[ -n "$issuer_file" && -f "$issuer_file" ]]; then
    cp "$issuer_file" "$sec_dir/issuer.pem"
    cat "$cert_file" "$issuer_file" > "$sec_dir/fullchain.pem"
  else
    cp "$cert_file" "$sec_dir/fullchain.pem"
  fi
  # Pebble root from management interface for openssl verify trust store.
  docker run --rm --network "$net" curlimages/curl:8.5.0 \
    -sk "https://pebble:15000/roots/0" > "$sec_dir/trusted_ca.pem" 2>/dev/null || true
  if ! grep -q "BEGIN CERTIFICATE" "$sec_dir/trusted_ca.pem" 2>/dev/null; then
    docker cp "$ctn:/test/certs/pebble.minica.pem" "$sec_dir/trusted_ca.pem" 2>/dev/null || true
  fi
  chmod 600 "$sec_dir/privkey.pem"
  chmod 644 "$sec_dir/fullchain.pem" "$sec_dir/cert.pem"

  # Prove chain: root + intermediate + leaf (before deleting extract)
  if [[ -f "$sec_dir/issuer.pem" && -s "$sec_dir/trusted_ca.pem" ]]; then
    openssl verify -CAfile "$sec_dir/trusted_ca.pem" -untrusted "$sec_dir/issuer.pem" "$sec_dir/cert.pem" >/dev/null 2>&1 \
      || soviez_migration_die MIGRATION_TLS_CHAIN_INVALID "Pebble chain verify failed"
  fi
  rm -rf "$sec_dir/extract"

  printf '%s|%s\n' "$sec_dir/fullchain.pem" "$sec_dir/privkey.pem"
}
