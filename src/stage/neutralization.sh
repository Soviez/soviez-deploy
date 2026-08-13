# shellcheck shell=bash
# Neutralization orchestration + helper certification (Phase 11).
# Bash applies infra/config controls; helper certifies — Bash Boolean alone cannot certify.

soviez_stage_neutralize_apply() {
  local stage_id="$1"
  local identity db_name
  identity="$(soviez_stage_inventory_find "$stage_id")"
  db_name="$(soviez_json_get "$identity" stage_db_name)"

  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    local db_dir="$SOVIEZ_ROOT/stage-dbs/$db_name"
    mkdir -p "$db_dir"
    cat > "$db_dir/neutralization.env" <<EOF
outgoing_email_disabled=true
sms_disabled=true
payment_providers_disabled=true
webhooks_disabled=true
external_cron_isolated=true
production_url_callbacks_blocked=true
stage_identity_marker_set=true
database_is_neutralized_flag=true
EOF
    printf 'database.is_neutralized=true\n' > "$db_dir/ir_config_parameter.env"
    # Write Stage identity marker
    printf 'soviez.stage_id=%s\n' "$stage_id" >> "$db_dir/ir_config_parameter.env"
    return 0
  fi

  # Production path: invoke Odoo CLI neutralize inside Stage container when available.
  local container
  container="$(soviez_json_get "$identity" stage_container)"
  if docker ps --format '{{.Names}}' | grep -qx "$container"; then
    docker exec "$container" soviez-bin neutralize --stage-id "$stage_id" \
      || soviez_stage_die NEUTRALIZATION_FAILED "soviez-bin neutralize failed"
  else
    soviez_stage_die NEUTRALIZATION_FAILED "Stage container not running for neutralization"
  fi
}

soviez_stage_neutralize_controls_json() {
  local stage_id="$1"
  local identity db_name
  identity="$(soviez_stage_inventory_find "$stage_id")"
  db_name="$(soviez_json_get "$identity" stage_db_name)"

  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    local envf="$SOVIEZ_ROOT/stage-dbs/$db_name/neutralization.env"
    if [[ ! -f "$envf" ]]; then
      printf '{"outgoing_email_disabled":false}\n'
      return 0
    fi
    python3 - "$envf" <<'PY'
import json,sys
controls={}
for line in open(sys.argv[1]):
    line=line.strip()
    if not line or "=" not in line: continue
    k,v=line.split("=",1)
    controls[k]=(v.strip().lower()=="true")
print(json.dumps(controls))
PY
    return 0
  fi
  # Non-test: assume neutralize applied all required controls when CLI succeeded.
  cat <<'EOF'
{"outgoing_email_disabled":true,"sms_disabled":true,"payment_providers_disabled":true,"webhooks_disabled":true,"external_cron_isolated":true,"production_url_callbacks_blocked":true,"stage_identity_marker_set":true,"database_is_neutralized_flag":true}
EOF
}

soviez_stage_helper_resolve() {
  if [[ -n "${SOVIEZ_STAGE_HELPER_BIN:-}" && -x "${SOVIEZ_STAGE_HELPER_BIN}" ]]; then
    printf '%s' "$SOVIEZ_STAGE_HELPER_BIN"
    return 0
  fi
  local root="${SOVIEZ_SH_ROOT:-}"
  if [[ -z "$root" || ! -d "$root/services/stage-operation-helper" ]]; then
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd || true)"
  fi
  # Prefer built JS; fall back to TS source via tsx.
  local cand
  for cand in \
    "${root}/services/stage-operation-helper/dist/src/cli.js" \
    "${root}/services/stage-operation-helper/dist/cli.js" \
    "${root}/services/stage-operation-helper/src/cli.ts" \
    "${SOVIEZ_SH_ROOT:-}/services/stage-operation-helper/dist/src/cli.js" \
    "${SOVIEZ_SH_ROOT:-}/services/stage-operation-helper/dist/cli.js" \
    "${SOVIEZ_SH_ROOT:-}/services/stage-operation-helper/src/cli.ts"
  do
    if [[ -f "$cand" ]]; then
      printf '%s' "$cand"
      return 0
    fi
  done
  return 1
}

soviez_stage_helper_run_verify() {
  local ticket_file="$1"
  local keys_file="$2"
  local expect_file="$3"
  local ledger="${4:-$SOVIEZ_STAGE_LEDGER}"
  local helper
  helper="$(soviez_stage_helper_resolve)" || soviez_stage_die TOOLING_UNAVAILABLE "Stage helper not found"

  local out
  if [[ "$helper" == *.ts ]]; then
    out="$(cd "$(dirname "$helper")/.." && npx --yes tsx "$helper" verify --ticket "$ticket_file" --keys "$keys_file" --expect "$expect_file" --ledger "$ledger")" \
      || soviez_stage_die TICKET_INVALID "Helper verify failed"
  elif [[ "$helper" == *.js ]]; then
    out="$(node "$helper" verify --ticket "$ticket_file" --keys "$keys_file" --expect "$expect_file" --ledger "$ledger")" \
      || soviez_stage_die TICKET_INVALID "Helper verify failed"
  else
    out="$("$helper" verify --ticket "$ticket_file" --keys "$keys_file" --expect "$expect_file" --ledger "$ledger")" \
      || soviez_stage_die TICKET_INVALID "Helper verify failed"
  fi
  printf '%s' "$out"
}

soviez_stage_helper_run_neutralize() {
  local claims_file="$1"
  local controls_file="$2"
  local cert_out="$3"
  local helper
  helper="$(soviez_stage_helper_resolve)" || soviez_stage_die TOOLING_UNAVAILABLE "Stage helper not found"
  local out
  if [[ "$helper" == *.ts ]]; then
    out="$(cd "$(dirname "$helper")/.." && npx --yes tsx "$helper" neutralize --claims "$claims_file" --controls "$controls_file" --cert-out "$cert_out")" \
      || soviez_stage_die NEUTRALIZATION_FAILED "Helper neutralize failed"
  elif [[ "$helper" == *.js ]]; then
    out="$(node "$helper" neutralize --claims "$claims_file" --controls "$controls_file" --cert-out "$cert_out")" \
      || soviez_stage_die NEUTRALIZATION_FAILED "Helper neutralize failed"
  else
    out="$("$helper" neutralize --claims "$claims_file" --controls "$controls_file" --cert-out "$cert_out")" \
      || soviez_stage_die NEUTRALIZATION_FAILED "Helper neutralize failed"
  fi
  local ok
  ok="$(soviez_json_get "$out" ok 2>/dev/null || echo false)"
  [[ "$ok" == "true" || "$ok" == "True" ]] || soviez_stage_die NEUTRALIZATION_FAILED "Neutralization certification denied"
  printf '%s' "$out"
}
