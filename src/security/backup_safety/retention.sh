# shellcheck shell=bash
# Security Gate S5 — backup retention cleanup (respects PRESERVE/INCIDENT/LEGAL_HOLD).

soviez_s5_backup_retention_cleanup() {
  local root="${1:-${SOVIEZ_S5_BACKUP_ROOT:-}}"
  if [[ -z "$root" ]]; then
    if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
      root="${TMPDIR:-/tmp}/soviez-s5-backups"
    else
      root="${SOVIEZ_ROOT:-/var/lib/soviez}/backups"
    fi
  fi
  [[ -d "$root" ]] || return 0

  local max_age_days="${SOVIEZ_S5_BACKUP_RETENTION_DAYS:-30}"
  local max_keep="${SOVIEZ_S5_BACKUP_RETENTION_MAX:-50}"

  local dirs=()
  local d
  while IFS= read -r d; do
    [[ -d "$d" ]] || continue
    if [[ -f "$d/PRESERVE" || -f "$d/INCIDENT" || -f "$d/LEGAL_HOLD" ]]; then
      continue
    fi
    dirs+=("$d")
  done < <(find "$root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)

  local n="${#dirs[@]}"
  if [[ "$n" -gt "$max_keep" ]]; then
    local drop=$((n - max_keep))
    local i
    for ((i=0; i<drop; i++)); do
      rm -rf "${dirs[$i]}"
    done
  fi

  find "$root" -mindepth 1 -maxdepth 1 -type d -mtime "+${max_age_days}" 2>/dev/null | while read -r d; do
    [[ -f "$d/PRESERVE" || -f "$d/INCIDENT" || -f "$d/LEGAL_HOLD" ]] && continue
    rm -rf "$d"
  done
  return 0
}
