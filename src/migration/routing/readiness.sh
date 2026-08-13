# shellcheck shell=bash

soviez_migration_routing_readiness_run() {
  local pair_id="${1:-}"
  soviez_migration_paths_init
  soviez_migration_assert_no_transfer
  soviez_migration_routing_assert_no_source_mutation
  soviez_migration_routing_assert_no_source_nginx_write

  local pair production_fqdn migration_fqdn inspection stored_fp warnings=() blockers=() result="PASS"
  pair="$(soviez_migration_load_pair "$pair_id")"
  production_fqdn="$(soviez_migration_domain_production_fqdn "$pair")"
  migration_fqdn="$(soviez_json_get "$pair" migration_fqdn)"
  [[ -n "$migration_fqdn" && "$migration_fqdn" != "null" ]] || \
    migration_fqdn="$(soviez_migration_domain_strategy_default "$production_fqdn")"

  inspection="$(soviez_migration_source_inspection_run "$pair")"
  stored_fp="$(soviez_json_get "$inspection" source_routing_fingerprint)"

  # DNS challenge verified?
  local dns_ok=0
  if [[ -d "$SOVIEZ_MIG_DNS_CHALLENGE_DIR" ]]; then
    dns_ok="$(SOVIEZ_PAIR="$pair_id" SOVIEZ_D="$SOVIEZ_MIG_DNS_CHALLENGE_DIR" python3 - <<'PY'
import json, os, pathlib
root=pathlib.Path(os.environ["SOVIEZ_D"])
ok=0
for p in root.glob("*/object.json"):
  try: d=json.loads(p.read_text())
  except Exception: continue
  if d.get("migration_pair_id")!=os.environ["SOVIEZ_PAIR"]: continue
  if d.get("status")=="verified": ok=1; break
print(ok)
PY
)"
  fi
  if [[ "$dns_ok" != "1" ]]; then
    blockers+=("dns_challenge_not_verified"); result="BLOCKED"
  fi

  # Landing prepared?
  local site_id site_dir
  site_id="$(soviez_migration_landing_site_id "$pair_id")"
  site_dir="$(soviez_migration_landing_site_dir "$site_id")"
  if [[ ! -f "$site_dir/www/index.html" ]]; then
    blockers+=("landing_not_prepared"); result="BLOCKED"
  elif ! soviez_migration_landing_health_check "$site_dir" >/dev/null 2>&1; then
    blockers+=("landing_health_failed"); result="BLOCKED"
  fi

  # TLS inventory?
  local inv_path
  inv_path="$(soviez_migration_tls_inventory_path "$pair_id" "$migration_fqdn")"
  if [[ ! -f "$inv_path" ]]; then
    blockers+=("tls_not_prepared"); result="BLOCKED"
  else
    local cert_path
    cert_path="$(soviez_json_get "$(cat "$inv_path")" certificate_path)"
    if ! soviez_migration_tls_verify_cert "$cert_path" "$migration_fqdn" 2>/dev/null; then
      blockers+=("tls_invalid"); result="BLOCKED"
    fi
  fi

  # Token must remain unconsumed
  if [[ "$(soviez_json_get "$pair" migration_token_consumed)" == "true" ]]; then
    blockers+=("token_consumed"); result="BLOCKED"
  fi

  # Source disruption
  if [[ "$(soviez_json_get "$(soviez_json_get "$inspection" health)" disruption_detected 2>/dev/null || echo false)" == "true" ]]; then
    blockers+=("source_disruption"); result="BLOCKED"
  fi

  # IPv6 optional unless explicitly required (OD-11)
  if [[ "${SOVIEZ_MIG_REQUIRE_IPV6:-0}" == "1" ]]; then
    if ! soviez_migration_dns_query "$migration_fqdn" AAAA authoritative | grep -q .; then
      warnings+=("ipv6_unreachable")
      [[ "$result" == "PASS" ]] && result="WARNING"
    fi
  fi

  local plan_id op_id expires plan_json routing_dir
  plan_id="$(soviez_migration_new_id rplan)"
  op_id="$(soviez_migration_new_id rt-op)"
  expires="$(soviez_migration_expires_iso "${SOVIEZ_MIG_ROUTING_PLAN_TTL_SECONDS:-86400}")"
  routing_dir="$(soviez_migration_routing_plan_dir "$plan_id")"
  mkdir -p "$routing_dir"
  local disabled_tpl
  disabled_tpl="$(soviez_migration_routing_disabled_erp_template "$routing_dir")"

  plan_json="$(SOVIEZ_RID="$plan_id" SOVIEZ_OP="$op_id" SOVIEZ_PAIR="$pair_id" SOVIEZ_RES="$result" \
    SOVIEZ_E="$expires" SOVIEZ_W="$(printf '%s\n' "${warnings[@]:-}" | python3 -c 'import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')" \
    SOVIEZ_B="$(printf '%s\n' "${blockers[@]:-}" | python3 -c 'import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')" \
    SOVIEZ_IN="$inspection" SOVIEZ_PF="$production_fqdn" SOVIEZ_MF="$migration_fqdn" \
    SOVIEZ_SID="$site_id" SOVIEZ_FP="$stored_fp" SOVIEZ_RD="$disabled_tpl" python3 - <<'PY'
import json, os, datetime
ins=json.loads(os.environ["SOVIEZ_IN"])
print(json.dumps({
  "schema_version": "soviez.migration_routing_plan.v1",
  "plan_id": os.environ["SOVIEZ_RID"],
  "operation_id": os.environ["SOVIEZ_OP"],
  "migration_pair_id": os.environ["SOVIEZ_PAIR"],
  "result": os.environ["SOVIEZ_RES"],
  "source_domain": os.environ["SOVIEZ_PF"],
  "migration_fqdn": os.environ["SOVIEZ_MF"],
  "source_routing_fingerprint": os.environ["SOVIEZ_FP"],
  "source_dns_observed": ins.get("dns"),
  "landing_site_id": os.environ["SOVIEZ_SID"],
  "disabled_erp_template": os.environ["SOVIEZ_RD"],
  "health_endpoints": {"landing": "/healthz"},
  "cutover_authorized": False,
  "payload_transfer_allowed": False,
  "destination_production_activated": False,
  "migration_token_consumed": False,
  "phase19_dependency": True,
  "warnings": json.loads(os.environ["SOVIEZ_W"]),
  "blockers": json.loads(os.environ["SOVIEZ_B"]),
  "issued_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
  "expires_at": os.environ["SOVIEZ_E"],
  "input_fingerprints": {"source_routing_fingerprint": os.environ["SOVIEZ_FP"]},
}, separators=(",", ":")))
PY
)"
  soviez_migration_report_sign_and_store routing "$plan_id" "$plan_json" >/dev/null
  mkdir -p "$SOVIEZ_MIG_ROOT/ops/$op_id"
  printf '{"operation_id":"%s","operation_type":"%s","current_state":"completed","pair_id":"%s","plan_id":"%s","result":"%s"}\n' \
    "$op_id" "$SOVIEZ_MIG_OP_ROUTING" "$pair_id" "$plan_id" "$result" > "$SOVIEZ_MIG_ROOT/ops/$op_id/state.json"

  if [[ "$result" == "PASS" ]]; then
    soviez_migration_phase18_banner "$result" || true
  fi
  cat "$(soviez_migration_routing_plan_dir "$plan_id")/object.json"
}

soviez_migration_routing_plan_show() {
  local plan_id="${1:-}"
  local path
  path="$(soviez_migration_routing_plan_dir "$plan_id")/object.json"
  [[ -f "$path" ]] || soviez_migration_die MIGRATION_NOT_FOUND "Unknown routing plan: $plan_id"
  if ! soviez_migration_verify_object_signature "$path"; then
    soviez_migration_die MIGRATION_PAIR_SIGNATURE_INVALID "Routing plan signature invalid"
  fi
  if soviez_migration_is_expired "$(soviez_json_get "$(cat "$path")" expires_at)"; then
    soviez_migration_die MIGRATION_ROUTING_NOT_READY "Routing plan expired"
  fi
  local report pair_id pair stored_fp
  report="$(cat "$path")"
  pair_id="$(soviez_json_get "$report" migration_pair_id)"
  pair="$(soviez_migration_load_pair "$pair_id")"
  stored_fp="$(soviez_json_get "$(soviez_json_get "$report" input_fingerprints)" source_routing_fingerprint)"
  soviez_migration_routing_drift_check "$pair" "$stored_fp"
  cat "$path"
}
