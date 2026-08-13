# shellcheck shell=bash

soviez_migration_phase23_readiness_drift() {
  local report_path="$1"
  # Invalidate when fingerprint env changes.
  local expected actual
  expected="$(soviez_json_get "$(cat "$report_path")" drift_fingerprint 2>/dev/null || true)"
  actual="${SOVIEZ_MIG_P22_DRIFT_FINGERPRINT:-stable}"
  if [[ -n "$expected" && "$expected" != "$actual" ]]; then
    soviez_migration_die MIGRATION_PHASE23_NOT_READY "phase23 readiness drift detected"
  fi
  return 0
}
