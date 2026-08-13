# shellcheck shell=bash

soviez_migration_p22_validate_observation_window() {
  local started_epoch="$1" ended_epoch="$2" required_seconds="$3"
  local span=$((ended_epoch - started_epoch))
  [[ "$span" -ge "$required_seconds" ]] || \
    soviez_migration_die MIGRATION_STABILIZATION_INCOMPLETE \
      "observation span ${span}s < required ${required_seconds}s (single instantaneous check insufficient)"
}
