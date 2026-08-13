# shellcheck shell=bash

soviez_migration_tls_revoke() {
  local pair_id="${1:-}" fqdn="${2:-}"
  soviez_migration_paths_init
  local sec_dir inv
  if [[ -n "$fqdn" ]]; then
    sec_dir="$(soviez_migration_tls_secrets_dir "$pair_id" "$fqdn")"
    rm -rf "$sec_dir"
    inv="$(soviez_migration_tls_inventory_path "$pair_id" "$fqdn")"
    rm -f "$inv"
  else
    rm -rf "$SOVIEZ_MIG_SECRETS_DIR/tls/$pair_id"
    rm -rf "$(soviez_migration_tls_dir "$pair_id")"
  fi
  printf '{"pair_id":"%s","fqdn":"%s","status":"revoked"}\n' "$pair_id" "$fqdn"
}

soviez_migration_tls_attach_landing() {
  local pair_id="$1" fqdn="$2" cert="$3" key="$4"
  local site_id site_dir
  site_id="$(soviez_migration_landing_site_id "$pair_id")"
  site_dir="$(soviez_migration_landing_site_dir "$site_id")"
  [[ -d "$site_dir" ]] || soviez_migration_die MIGRATION_LANDING_PREPARE_FAILED "Landing not prepared"
  soviez_migration_landing_write_nginx "$site_dir" "$fqdn" "$cert" "$key"
  production_fqdn="$(soviez_migration_domain_production_fqdn "$(soviez_migration_load_pair "$pair_id")")"
  soviez_migration_landing_validate_nginx "$site_dir/nginx.conf" "$fqdn" "$production_fqdn"
}

soviez_migration_tls_prepare() {
  local pair_id="${1:-}" fqdn_override="${2:-}"
  soviez_migration_paths_init
  soviez_migration_assert_no_transfer

  local pair production_fqdn fqdn cert key paths cert_path key_path issuer not_after inv_path
  pair="$(soviez_migration_load_pair "$pair_id")"
  production_fqdn="$(soviez_migration_domain_production_fqdn "$pair")"
  fqdn="$fqdn_override"
  [[ -n "$fqdn" ]] || fqdn="$(soviez_json_get "$pair" migration_fqdn)"
  [[ -n "$fqdn" && "$fqdn" != "null" ]] || fqdn="$(soviez_migration_domain_strategy_default "$production_fqdn")"

  soviez_migration_tls_policy_assert "$fqdn" "$production_fqdn" "public"

  if [[ "${SOVIEZ_MIG_ACME_PEBBLE:-0}" == "1" ]]; then
    paths="$(soviez_migration_tls_acme_issue "$pair_id" "$fqdn")"
  elif [[ "${SOVIEZ_MIG_TLS_FIXTURE:-1}" == "1" || "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    paths="$(soviez_migration_tls_fixture_issue "$pair_id" "$fqdn")"
  else
    paths="$(soviez_migration_tls_acme_issue "$pair_id" "$fqdn")"
  fi
  cert_path="${paths%%|*}"
  key_path="${paths#*|}"
  local ca_path
  ca_path="$(dirname "$cert_path")/trusted_ca.pem"
  [[ -f "$ca_path" ]] || ca_path="$(soviez_migration_tls_fixture_ca_dir)/ca.crt"
  local leaf="${cert_path%/*}/cert.pem"
  [[ -f "$leaf" ]] || leaf="$cert_path"
  soviez_migration_tls_verify_cert "$leaf" "$fqdn" "$ca_path"

  issuer="$(openssl x509 -in "$cert_path" -noout -issuer 2>/dev/null | sed 's/issuer= //')"
  not_after="$(openssl x509 -in "$cert_path" -noout -enddate 2>/dev/null | sed 's/notAfter=//')"
  inv_path="$(soviez_migration_tls_inventory_path "$pair_id" "$fqdn")"
  mkdir -p "$(dirname "$inv_path")"
  SOVIEZ_OUT="$inv_path" SOVIEZ_PID="$pair_id" SOVIEZ_F="$fqdn" SOVIEZ_C="$cert_path" \
    SOVIEZ_K="$key_path" SOVIEZ_I="$issuer" SOVIEZ_N="$not_after" python3 - <<'PY'
import json, os, datetime
inv={
  "schema_version": "soviez.migration_tls_inventory.v1",
  "pair_id": os.environ["SOVIEZ_PID"],
  "fqdn": os.environ["SOVIEZ_F"],
  "certificate_path": os.environ["SOVIEZ_C"],
  "private_key_path": os.environ["SOVIEZ_K"],
  "issuer": os.environ["SOVIEZ_I"],
  "not_after": os.environ["SOVIEZ_N"],
  "private_key_included": False,
  "created_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
}
open(os.environ["SOVIEZ_OUT"], "w").write(json.dumps(inv, separators=(",", ":")))
PY
  chmod 600 "$inv_path"

  if [[ -d "$(soviez_migration_landing_site_dir "$(soviez_migration_landing_site_id "$pair_id")")" ]]; then
    soviez_migration_tls_attach_landing "$pair_id" "$fqdn" "$cert_path" "$key_path"
  fi

  cat "$inv_path"
}
