# shellcheck shell=bash
# Phase 21 source lifecycle: migration_origin_grace -> cutover_freeze ->
# cutover_maintenance -> (rollback_origin | terminal). Never purges or
# archives the source (that remains exclusively Phase 22 scope).

soviez_migration_source_transition_state_path() {
  local auth_id="$1"
  printf '%s/source_transition/%s/state.json\n' "$SOVIEZ_MIG_ROOT" "$auth_id"
}

soviez_migration_source_transition_set() {
  local auth_id="$1" state="$2"
  local f
  f="$(soviez_migration_source_transition_state_path "$auth_id")"
  mkdir -p "$(dirname "$f")"
  SOVIEZ_OUT="$f" SOVIEZ_AUTH="$auth_id" SOVIEZ_ST="$state" python3 - <<'PY'
import json, os, time
print(json.dumps({
  "authorization_id": os.environ["SOVIEZ_AUTH"],
  "state": os.environ["SOVIEZ_ST"],
  "updated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
}, separators=(",", ":")), file=open(os.environ["SOVIEZ_OUT"], "w"))
PY
  cat "$f"
}

soviez_migration_source_transition_get() {
  local auth_id="$1"
  local f
  f="$(soviez_migration_source_transition_state_path "$auth_id")"
  if [[ -f "$f" ]]; then
    cat "$f"
  else
    printf '{"authorization_id":"%s","state":"migration_origin_grace"}\n' "$auth_id"
  fi
}

soviez_migration_source_transition_to_freeze() {
  local auth_id="${1:-}"
  [[ -n "$auth_id" ]] || soviez_migration_die MIGRATION_AUTHORIZATION_REQUIRED "authorization-id required"
  soviez_migration_assert_phase21_cutover_allowed "$SOVIEZ_MIG_OP_SOURCE_MAINTENANCE"
  local cur
  cur="$(soviez_json_get "$(soviez_migration_source_transition_get "$auth_id")" state)"
  case "$cur" in
    cutover_freeze|cutover_maintenance|rollback_origin)
      soviez_migration_source_transition_get "$auth_id"
      return 0
      ;;
    migration_origin_grace|"")
      soviez_migration_source_transition_set "$auth_id" "cutover_freeze"
      ;;
    *)
      soviez_migration_die MIGRATION_SOURCE_MAINTENANCE_FAILED "invalid transition to cutover_freeze from $cur"
      ;;
  esac
}

soviez_migration_source_transition_write_maintenance_page() {
  local fqdn="$1"
  local root site body sig
  root="$(soviez_migration_p21_nginx_root)"
  site="$root/source/www"
  mkdir -p "$site"
  body='<html><body><h1>Scheduled migration in progress</h1><p>This system is temporarily unavailable during a planned, previously announced migration. No tracking scripts are loaded on this page.</p></body></html>'
  printf '%s' "$body" > "$site/index.html"
  sig="$(soviez_migration_sign_json "$body")"
  printf '{"fqdn":"%s","signature":"%s","tracking":false}\n' "$fqdn" "$sig" > "$site/maintenance.json"
}

soviez_migration_source_transition_to_maintenance() {
  local auth_id="${1:-}" fqdn="${2:-}"
  [[ -n "$auth_id" && -n "$fqdn" ]] || soviez_migration_die MIGRATION_AUTHORIZATION_REQUIRED "authorization-id and fqdn required"
  soviez_migration_assert_phase21_cutover_allowed "$SOVIEZ_MIG_OP_SOURCE_MAINTENANCE"
  local cur
  cur="$(soviez_json_get "$(soviez_migration_source_transition_get "$auth_id")" state)"
  if [[ "$cur" == "cutover_maintenance" ]]; then
    soviez_migration_source_transition_get "$auth_id"
    return 0
  fi
  [[ "$cur" == "cutover_freeze" ]] || \
    soviez_migration_die MIGRATION_SOURCE_MAINTENANCE_FAILED "invalid transition to cutover_maintenance from $cur"
  soviez_migration_p21_nginx_source_maintenance "$fqdn" >/dev/null
  soviez_migration_source_transition_write_maintenance_page "$fqdn"
  soviez_migration_source_transition_set "$auth_id" "cutover_maintenance"
}

# AR-09: business writes are denied for the source once frozen/maintenance.
soviez_migration_source_transition_deny_writes() {
  local auth_id="${1:-}"
  local cur
  cur="$(soviez_json_get "$(soviez_migration_source_transition_get "$auth_id")" state)"
  case "$cur" in
    cutover_freeze|cutover_maintenance)
      soviez_migration_die MIGRATION_SOURCE_MAINTENANCE_FAILED "AR-09 business writes denied while source is $cur"
      ;;
  esac
  return 0
}

soviez_migration_source_transition_to_rollback_origin() {
  local auth_id="${1:-}"
  [[ -n "$auth_id" ]] || soviez_migration_die MIGRATION_AUTHORIZATION_REQUIRED "authorization-id required"
  soviez_migration_source_transition_set "$auth_id" "rollback_origin"
}
