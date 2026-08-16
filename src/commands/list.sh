# shellcheck shell=bash
# List every Soviez-managed environment on this server (local-only).

soviez_cmd_list_run() {
  printf '%-11s %-16s %-40s %s\n' "TYPE" "ID" "DOMAIN" "STATUS"
  local found=0

  # Productions from tenant identity files
  local tenant_root
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    tenant_root="${SOVIEZ_ROOT}/tenant"
  else
    tenant_root="${SOVIEZ_TENANT_DIR:-/var/soviez/tenant}"
  fi
  if [[ -d "$tenant_root" ]]; then
    local ident id domain status
    while IFS= read -r -d '' ident; do
      id="$(soviez_json_get "$(cat "$ident")" id 2>/dev/null || soviez_json_get "$(cat "$ident")" production_id 2>/dev/null || basename "$(dirname "$ident")")"
      domain="$(soviez_json_get "$(cat "$ident")" domain 2>/dev/null || soviez_json_get "$(cat "$ident")" production_domain 2>/dev/null || echo "-")"
      status="$(soviez_json_get "$(cat "$ident")" lifecycle_status 2>/dev/null || echo "unknown")"
      # Map common statuses for display
      case "$status" in
        running|active) status="Running" ;;
        stopped) status="Stopped" ;;
        *) status="${status:-unknown}" ;;
      esac
      printf '%-11s %-16s %-40s %s\n' "Production" "$id" "$domain" "$status"
      found=1
    done < <(find "$tenant_root" -type f -name 'identity.json' -print0 2>/dev/null)
  fi

  # Legacy env sheets (best-effort)
  local envf
  for envf in /root/.soviez_*.env "${SOVIEZ_ROOT:-}/.soviez_*.env"; do
    [[ -f "$envf" ]] || continue
    # shellcheck disable=SC1090
    domain="$(grep -E '^DOMAIN=' "$envf" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"' || true)"
    id="$(basename "$envf" | sed 's/^\.soviez_//;s/\.env$//')"
    status="Unknown"
    if command -v docker >/dev/null 2>&1; then
      if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "soviez-web-${id}"; then
        status="Running"
      elif docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "soviez-web-${id}"; then
        status="Stopped"
      fi
    fi
    printf '%-11s %-16s %-40s %s\n' "Production" "$id" "${domain:--}" "$status"
    found=1
  done

  # Stages
  if declare -F soviez_stage_paths_init >/dev/null 2>&1; then
    soviez_stage_paths_init 2>/dev/null || true
  fi
  if declare -F soviez_stage_inventory_list_ids >/dev/null 2>&1; then
    local sid ident domain status
    while IFS= read -r sid; do
      [[ -z "$sid" ]] && continue
      ident="$(soviez_stage_inventory_find "$sid" 2>/dev/null || true)"
      [[ -n "$ident" ]] || continue
      domain="$(soviez_json_get "$ident" stage_domain 2>/dev/null || echo "-")"
      status="$(soviez_json_get "$ident" lifecycle_status 2>/dev/null || echo unknown)"
      case "$status" in
        running) status="Running" ;;
        stopped|certified) status="Stopped" ;;
      esac
      printf '%-11s %-16s %-40s %s\n' "Stage" "$sid" "$domain" "$status"
      found=1
    done < <(soviez_stage_inventory_list_ids 2>/dev/null || true)
  fi

  if [[ "$found" -eq 0 ]]; then
    printf '%-11s %-16s %-40s %s\n' "-" "-" "-" "No environments found"
  fi
}
