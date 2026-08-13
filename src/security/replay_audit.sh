# shellcheck shell=bash
# Phase 24 — ticket purpose separation / replay audit helpers (no new engine).

soviez_security_ticket_purpose_assert() {
  local ticket_purpose="$1" allowed="$2"
  [[ "$ticket_purpose" == "$allowed" ]] && return 0
  soviez_security_die SECURITY_TICKET_PURPOSE_MISMATCH "ticket=$ticket_purpose allowed=$allowed"
}

# Deny cross-purpose confusion for common ticket kinds.
soviez_security_ticket_deny_confusion() {
  local purpose="$1" attempted_op="$2"
  case "$purpose:$attempted_op" in
    registry_pull:update_apply|registry_pull:activation|registry_pull:migration_auth) ;;
    offline_update:activation|offline_update:registry_pull|offline_update:migration_auth) ;;
    migration_auth:registry_pull|migration_auth:update_apply|migration_auth:activation) ;;
    stage_operation:production_update|stage_operation:registry_pull) ;;
    *)
      # Matching purpose:ok
      [[ "$purpose" == "$attempted_op" ]] && return 0
      [[ "$attempted_op" == "${purpose}"* ]] && return 0
      ;;
  esac
  # If pattern matched deny list pairs above:
  case "$purpose:$attempted_op" in
    registry_pull:update_apply|registry_pull:activation|registry_pull:migration_auth|\
    offline_update:activation|offline_update:registry_pull|offline_update:migration_auth|\
    migration_auth:registry_pull|migration_auth:update_apply|migration_auth:activation|\
    stage_operation:production_update|stage_operation:registry_pull)
      soviez_security_die SECURITY_TICKET_PURPOSE_MISMATCH "$purpose cannot authorize $attempted_op"
      ;;
  esac
  return 0
}
