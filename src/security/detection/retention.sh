# shellcheck shell=bash
# Security Gate S3 — evidence retention (bounded; respects PRESERVE/INCIDENT/LEGAL_HOLD).

soviez_s3_retention_cleanup() {
  local root
  root="$(soviez_s3_evidence_root)"
  local max_age_days="${SOVIEZ_S3_RETENTION_DAYS:-30}"
  local max_runs="${SOVIEZ_S3_RETENTION_MAX_RUNS:-50}"
  [[ -d "$root" ]] || return 0
  # Delete oldest non-preserved runs beyond max_runs
  local runs=()
  local d
  while IFS= read -r d; do
    [[ -d "$d" ]] || continue
    if [[ -f "$d/PRESERVE" || -f "$d/INCIDENT" || -f "$d/LEGAL_HOLD" ]]; then
      continue
    fi
    runs+=("$d")
  done < <(find "$root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
  local n="${#runs[@]}"
  if [[ "$n" -gt "$max_runs" ]]; then
    local drop=$((n - max_runs))
    local i
    for ((i=0; i<drop; i++)); do
      rm -rf "${runs[$i]}"
    done
  fi
  # Age-based
  find "$root" -mindepth 1 -maxdepth 1 -type d -mtime "+${max_age_days}" 2>/dev/null | while read -r d; do
    [[ -f "$d/PRESERVE" || -f "$d/INCIDENT" || -f "$d/LEGAL_HOLD" ]] && continue
    rm -rf "$d"
  done
  return 0
}
