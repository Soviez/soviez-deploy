# shellcheck shell=bash

soviez_migration_p22_health_sample_ok() {
  local sample="$1"
  local f
  for f in http tls db filestore workers cron mail webhook payment queue backups growth license_guard dns stages; do
    [[ "$(soviez_json_get "$sample" "$f")" == "ok" || "$(soviez_json_get "$sample" "$f")" == "True" ]] || return 1
  done
  local errors latency
  errors="$(soviez_json_get "$sample" errors)"
  latency="$(soviez_json_get "$sample" latency_ms)"
  [[ "${errors:-0}" -eq 0 ]] || return 1
  [[ "${latency:-0}" -le "${SOVIEZ_MIG_P22_MAX_LATENCY_MS:-2000}" ]] || return 1
  [[ "$(soviez_json_get "$sample" source_writes)" -eq 0 ]] || return 1
  [[ "$(soviez_json_get "$sample" incidents)" -eq 0 ]] || return 1
  return 0
}
