# shellcheck shell=bash

soviez_migration_dns_challenge_create() {
  local pair_id="${1:-}" plan_id="${2:-}"
  soviez_migration_paths_init
  soviez_migration_assert_no_transfer

  local pair prod_id prod_domain migration_fqdn bootstrap_id dst_fp license_id
  pair="$(soviez_migration_load_pair "$pair_id")"
  prod_id="$(soviez_json_get "$pair" source_production_id)"
  prod_domain="$(soviez_migration_domain_production_fqdn "$pair")"
  migration_fqdn="$(soviez_json_get "$pair" migration_fqdn)"
  if [[ -z "$migration_fqdn" || "$migration_fqdn" == "null" ]]; then
    migration_fqdn="$(soviez_migration_domain_strategy_default "$prod_domain")"
  fi
  soviez_migration_domain_assert_migration_fqdn "$migration_fqdn" "$prod_domain"
  bootstrap_id="$(soviez_json_get "$pair" destination_bootstrap_id)"
  dst_fp="$(soviez_json_get "$pair" destination_fingerprint)"
  license_id="$(soviez_json_get "$pair" source_license_id)"

  local challenge_id op_id nonce expires payload sig txt_name txt_value challenge_json
  challenge_id="$(soviez_migration_new_id dns-ch)"
  op_id="$(soviez_migration_new_id dns-op)"
  nonce="$(openssl rand -hex 16)"
  expires="$(soviez_migration_expires_iso "${SOVIEZ_MIG_DNS_CHALLENGE_TTL_SECONDS:-1800}")"
  payload="$(soviez_migration_dns_challenge_binding_payload "$pair_id" "$prod_id" "$prod_domain" \
    "$migration_fqdn" "$bootstrap_id" "$dst_fp" "$license_id" "$op_id" "$nonce" "$expires")"
  sig="$(soviez_migration_dns_challenge_sign "$payload")"
  txt_name="$(soviez_migration_dns_challenge_txt_name "$migration_fqdn")"
  txt_value="$(soviez_migration_dns_challenge_txt_value "$challenge_id" "$sig")"

  challenge_json="$(SOVIEZ_CID="$challenge_id" SOVIEZ_OP="$op_id" SOVIEZ_PAIR="$pair_id" \
    SOVIEZ_PLAN="$plan_id" SOVIEZ_MF="$migration_fqdn" SOVIEZ_PF="$prod_domain" \
    SOVIEZ_TN="$txt_name" SOVIEZ_TV="$txt_value" SOVIEZ_SIG="$sig" SOVIEZ_NON="$nonce" \
    SOVIEZ_EXP="$expires" SOVIEZ_PAY="$payload" SOVIEZ_PID="$prod_id" SOVIEZ_L="$license_id" \
    SOVIEZ_B="$bootstrap_id" SOVIEZ_DF="$dst_fp" python3 - <<'PY'
import json, os, datetime
print(json.dumps({
  "schema_version": "soviez.migration_dns_challenge.v1",
  "challenge_id": os.environ["SOVIEZ_CID"],
  "operation_id": os.environ["SOVIEZ_OP"],
  "migration_pair_id": os.environ["SOVIEZ_PAIR"],
  "domain_plan_id": os.environ.get("SOVIEZ_PLAN") or "",
  "migration_fqdn": os.environ["SOVIEZ_MF"],
  "production_fqdn": os.environ["SOVIEZ_PF"],
  "source_production_id": os.environ["SOVIEZ_PID"],
  "destination_bootstrap_id": os.environ["SOVIEZ_B"],
  "destination_fingerprint": os.environ["SOVIEZ_DF"],
  "license_id": os.environ["SOVIEZ_L"],
  "txt_record": {"name": os.environ["SOVIEZ_TN"], "value": os.environ["SOVIEZ_TV"], "ttl": 300},
  "expected_reachability": {"a": [], "aaaa": [], "cname": []},
  "binding_payload": os.environ["SOVIEZ_PAY"],
  "binding_signature": os.environ["SOVIEZ_SIG"],
  "nonce": os.environ["SOVIEZ_NON"],
  "issued_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
  "expires_at": os.environ["SOVIEZ_EXP"],
  "status": "pending",
  "consumed": False,
  "provider_created": False,
}, separators=(",", ":")))
PY
)"
  soviez_migration_report_sign_and_store dns_challenge "$challenge_id" "$challenge_json" >/dev/null
  mkdir -p "$SOVIEZ_MIG_ROOT/ops/$op_id"
  printf '{"operation_id":"%s","operation_type":"%s","current_state":"pending","pair_id":"%s","challenge_id":"%s"}\n' \
    "$op_id" "$SOVIEZ_MIG_OP_DNS_CHALLENGE" "$pair_id" "$challenge_id" > "$SOVIEZ_MIG_ROOT/ops/$op_id/state.json"
  cat "$(soviez_migration_dns_challenge_dir "$challenge_id")/object.json"
}

soviez_migration_dns_challenge_load() {
  local challenge_id="$1"
  local path
  path="$(soviez_migration_dns_challenge_dir "$challenge_id")/object.json"
  [[ -f "$path" ]] || soviez_migration_die MIGRATION_DNS_CHALLENGE_REQUIRED "Unknown challenge: $challenge_id"
  cat "$path"
}

soviez_migration_dns_challenge_verify() {
  local challenge_id="${1:-}"
  soviez_migration_paths_init
  soviez_migration_assert_no_transfer

  local challenge path txt_name txt_value sig payload status consumed expires
  challenge="$(soviez_migration_dns_challenge_load "$challenge_id")"
  path="$(soviez_migration_dns_challenge_dir "$challenge_id")/object.json"
  if ! soviez_migration_verify_object_signature "$path"; then
    soviez_migration_die MIGRATION_DNS_CHALLENGE_INVALID "Challenge signature invalid"
  fi
  status="$(soviez_json_get "$challenge" status)"
  consumed="$(soviez_json_get "$challenge" consumed)"
  expires="$(soviez_json_get "$challenge" expires_at)"
  [[ "$consumed" != "true" && "$consumed" != "True" ]] || \
    soviez_migration_die MIGRATION_DNS_CHALLENGE_REPLAY_DENIED "Challenge already consumed"
  if soviez_migration_is_expired "$expires"; then
    soviez_migration_die MIGRATION_DNS_CHALLENGE_EXPIRED "Challenge expired"
  fi
  soviez_migration_dns_replay_assert_fresh "$challenge_id"

  payload="$(soviez_json_get "$challenge" binding_payload)"
  sig="$(soviez_json_get "$challenge" binding_signature)"
  soviez_migration_dns_challenge_verify_sig "$payload" "$sig" || \
    soviez_migration_die MIGRATION_DNS_CHALLENGE_INVALID "Binding signature mismatch"

  txt_name="$(soviez_json_get "$(soviez_json_get "$challenge" txt_record)" name)"
  txt_value="$(soviez_json_get "$(soviez_json_get "$challenge" txt_record)" value)"

  if ! soviez_migration_dns_authoritative_match "$txt_name" TXT "$txt_value"; then
    soviez_migration_die MIGRATION_DNS_RECORD_MISMATCH "Authoritative TXT mismatch"
  fi
  if ! soviez_migration_dns_public_resolvers_agree "$txt_name" TXT "$txt_value"; then
    soviez_migration_die MIGRATION_DNS_PROPAGATION_PENDING "Public resolver propagation pending"
  fi
  if ! soviez_migration_dns_public_vs_authoritative "$txt_name" TXT; then
    soviez_migration_die MIGRATION_DNS_AUTHORITATIVE_MISMATCH "Authoritative vs public mismatch"
  fi

  # Reachability A/AAAA/CNAME for migration FQDN
  local mig_fqdn a_ok
  mig_fqdn="$(soviez_json_get "$challenge" migration_fqdn)"
  a_ok=1
  if soviez_migration_dns_query "$mig_fqdn" A authoritative | grep -q .; then a_ok=0; fi
  if soviez_migration_dns_query "$mig_fqdn" AAAA authoritative | grep -q .; then a_ok=0; fi
  if soviez_migration_dns_query "$mig_fqdn" CNAME authoritative | grep -q .; then a_ok=0; fi
  if [[ "$a_ok" -ne 0 ]]; then
    soviez_migration_die MIGRATION_IPV4_UNREACHABLE "Migration FQDN reachability record missing"
  fi

  soviez_migration_dns_replay_mark "$challenge_id"
  SOVIEZ_P="$path" python3 - <<'PY'
import json, os, datetime
p=os.environ["SOVIEZ_P"]
d=json.load(open(p))
d["status"]="verified"
d["consumed"]=True
d["verified_at"]=datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
open(p,"w").write(json.dumps(d, separators=(",", ":")))
PY
  soviez_migration_sign_object_file "$path"
  cat "$path"
}
