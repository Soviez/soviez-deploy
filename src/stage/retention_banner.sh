# shellcheck shell=bash
# Phase 13 — neutralized Stage retention banner and warning ledger.

soviez_retention_html_escape() {
  SOVIEZ_TEXT="$1" python3 - <<'PY'
import html, os
print(html.escape(os.environ["SOVIEZ_TEXT"], quote=True))
PY
}

soviez_retention_render_banner() {
  local stage_id="$1" rec deadline days phrase date maxd status text escaped line2 line3
  soviez_retention_ensure "$stage_id"
  soviez_retention_refresh_derived "$stage_id"
  rec="$(soviez_retention_read "$stage_id")"
  deadline="$(soviez_json_get "$rec" current_retention_deadline)"
  days="$(soviez_json_get "$rec" days_remaining)"
  phrase="$(soviez_retention_remaining_phrase "$days")"
  date="$(soviez_retention_format_date_display "$deadline")"
  maxd="$(soviez_retention_format_date_display "$(soviez_json_get "$rec" maximum_retention_deadline)")"
  status="$(soviez_json_get "$rec" retention_status)"

  local line1
  line1="Stage environment · Neutralized · ${phrase}"
  case "$status" in
    needs_action|deletion_blocked|recovery_required)
      line1="Stage environment · Neutralized · Deletion overdue — Needs Action"
      line2="Automatic deletion was blocked to protect Stage data."
      line3="Scheduled deletion: ${date} (timezone ${SOVIEZ_RETENTION_HOST_TZ})"
      ;;
    deletion_due)
      line2="Automatic deletion is pending Safe Shield verification."
      line3="Scheduled deletion: ${date}"
      ;;
    extension_limit_reached)
      line2="Scheduled deletion: ${date}"
      line3="Maximum 60-day retention applied."
      ;;
    *)
      line2="Scheduled deletion: ${date}"
      if [[ "$status" == "extension_available" ]]; then
        line3="Retention may be extended up to ${maxd}."
      else
        line3="Timezone: ${SOVIEZ_RETENTION_HOST_TZ}"
      fi
      ;;
  esac

  text="$(printf '%s\n%s\n%s' "$line1" "$line2" "$line3")"
  mkdir -p "$(soviez_stage_config_path "$stage_id")"
  printf '%s\n' "$text" > "$(soviez_retention_banner_file "$stage_id")"
  escaped="$(soviez_retention_html_escape "$text")"
  printf '<aside class="soviez-retention-banner" role="status" data-soviez-stage-banner="retention">%s</aside>\n' \
    "$(printf '%s' "$escaped" | sed 's/$/<br>/' | tr -d '\n')" \
    > "$(soviez_retention_banner_html_file "$stage_id")"
  chmod 640 "$(soviez_retention_banner_file "$stage_id")" "$(soviez_retention_banner_html_file "$stage_id")" 2>/dev/null || true

  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    local ident db marker
    ident="$(soviez_stage_inventory_find "$stage_id" 2>/dev/null || true)"
    if [[ -n "$ident" ]]; then
      db="$(soviez_json_get "$ident" stage_db_name)"
      marker="$SOVIEZ_ROOT/stage-dbs/$db/retention_banner.txt"
      mkdir -p "$(dirname "$marker")"
      printf '%s\n' "$text" > "$marker"
    fi
  fi
  printf '%s\n' "$text"
}

soviez_retention_evaluate_warnings() {
  local stage_id="$1" rec days threshold file t
  soviez_retention_ensure "$stage_id"
  soviez_retention_refresh_derived "$stage_id"
  rec="$(soviez_retention_read "$stage_id")"
  days="$(soviez_json_get "$rec" days_remaining)"
  file="$(soviez_retention_warnings_file "$stage_id")"
  mkdir -p "$(dirname "$file")"; touch "$file"; chmod 600 "$file"

  for t in 30 14 7 3 1 0; do
    if [[ "$days" == "$t" ]]; then
      threshold="$t"
      if python3 - "$file" "$threshold" <<'PY'
import json, sys
for line in open(sys.argv[1], encoding="utf-8"):
    try:
        if json.loads(line).get("threshold") == int(sys.argv[2]):
            raise SystemExit(0)
    except json.JSONDecodeError:
        pass
raise SystemExit(1)
PY
      then
        continue
      fi
      SOVIEZ_SID="$stage_id" SOVIEZ_THRESHOLD="$threshold" SOVIEZ_NOW="$(soviez_retention_now_utc)" python3 - <<'PY' >> "$file"
import json, os
print(json.dumps({"stage_id":os.environ["SOVIEZ_SID"],"threshold":int(os.environ["SOVIEZ_THRESHOLD"]),"warned_at":os.environ["SOVIEZ_NOW"]},separators=(",",":")))
PY
      soviez_retention_patch "$stage_id" "$(SOVIEZ_T="$threshold" python3 - <<'PY'
import json, os
print(json.dumps({"last_warning_threshold": int(os.environ["SOVIEZ_T"])}, separators=(",", ":")))
PY
)"
      soviez_log_info "Retention warning emitted for Stage $stage_id threshold=$threshold"
    fi
  done
  if [[ "$days" -lt 0 ]]; then
    if ! python3 - "$file" -1 <<'PY'
import json, sys
for line in open(sys.argv[1], encoding="utf-8"):
    try:
        if json.loads(line).get("threshold") == int(sys.argv[2]):
            raise SystemExit(0)
    except json.JSONDecodeError:
        pass
raise SystemExit(1)
PY
    then
      SOVIEZ_SID="$stage_id" SOVIEZ_NOW="$(soviez_retention_now_utc)" python3 - <<'PY' >> "$file"
import json, os
print(json.dumps({"stage_id":os.environ["SOVIEZ_SID"],"threshold":-1,"warned_at":os.environ["SOVIEZ_NOW"]},separators=(",",":")))
PY
    fi
  fi
}
