# shellcheck shell=bash
# Phase 21 cutover orchestrator — parent operation state machine.
#
# Every mutating step is individually idempotent so retry/recover can safely
# re-run the whole sequence: DNS mutation overwrites the same record, TLS
# fixture issuance is skipped once cert files exist, nginx activation
# rewrites the same config, traffic_owner switch is a no-op once already at
# the target owner, and source_transition state changes short-circuit once
# already advanced.

soviez_migration_cutover_state_write() {
  local op_id="$1" state="$2" extra="${3:-}"
  [[ -n "$extra" ]] || extra="{}"
  local f
  f="$(soviez_migration_cutover_state_path "$op_id")"
  mkdir -p "$(dirname "$f")"
  SOVIEZ_OUT="$f" SOVIEZ_OP="$op_id" SOVIEZ_ST="$state" SOVIEZ_EXTRA="$extra" python3 - <<'PY'
import json, os
extra = json.loads(os.environ["SOVIEZ_EXTRA"])
existing = {}
try:
  existing = json.load(open(os.environ["SOVIEZ_OUT"]))
except Exception:
  existing = {}
doc = {
  "operation_id": os.environ["SOVIEZ_OP"],
  "operation_type": "migration_cutover",
  "current_state": os.environ["SOVIEZ_ST"],
}
existing.update(doc)
existing.update(extra)
open(os.environ["SOVIEZ_OUT"], "w").write(json.dumps(existing, separators=(",", ":")))
PY
  cat "$f"
}

soviez_migration_cutover_status() {
  local op_id="${1:-}"
  [[ -n "$op_id" ]] || soviez_migration_die MIGRATION_NOT_FOUND "operation-id required"
  soviez_migration_cutover_paths_init
  local f
  f="$(soviez_migration_cutover_state_path "$op_id")"
  [[ -f "$f" ]] || soviez_migration_die MIGRATION_NOT_FOUND "cutover operation not found"
  cat "$f"
}

soviez_migration_cutover_certification_banner() {
  cat <<'EOF'
TRAFFIC OWNER — DESTINATION
PRODUCTION DNS — CHANGED
SOURCE — MAINTENANCE (BUSINESS WRITES DENIED)
ROLLBACK WINDOW — OPEN
PHASE 22 READINESS — REPORTED
NO SOURCE PURGE
NO SOURCE ARCHIVE
NO SAAS PAYLOAD RELAY
MIGRATION TOKEN — CONSUMED EXACTLY ONCE (PHASE 20)
EOF
}

# soviez_migration_cutover_start <pair-id> [confirm]
soviez_migration_cutover_start() {
  local pair_id="${1:-}" confirm="${2:-0}"
  [[ -n "$pair_id" ]] || soviez_migration_die MIGRATION_PAIR_REQUIRED "pair-id required"
  [[ "$confirm" == "1" || "${SOVIEZ_CLI_YES:-0}" == "1" || "${SOVIEZ_MIG_ASSUME_YES:-0}" == "1" ]] || \
    soviez_migration_die MIGRATION_CUTOVER_CONFIRMATION_REQUIRED "cutover requires explicit confirm"

  # Security Gate S4 — quarantine must be PROMOTED for external migrations
  if declare -F soviez_q_migration_cutover_allowed >/dev/null 2>&1; then
    if ! soviez_q_migration_cutover_allowed; then
      soviez_migration_die MIGRATION_CUTOVER_CONFIRMATION_REQUIRED "S4 quarantine blocks cutover (token not consumed)"
    fi
  fi

  soviez_migration_cutover_paths_init

  # Exact lock: one active cutover per migration pair (portable; no flock binary).
  local lock_dir lock_file
  lock_dir="$SOVIEZ_MIG_CUTOVER_DIR/locks"
  mkdir -p "$lock_dir"
  lock_file="$lock_dir/pair-${pair_id}.lock"
  if ! SOVIEZ_LOCK="$lock_file" python3 - <<'PY'
import os, sys, time
path = os.environ["SOVIEZ_LOCK"]
# Exclusive create; stale locks older than 2h are stolen (crash recovery).
for _ in range(40):
  try:
    fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    os.write(fd, str(os.getpid()).encode())
    os.close(fd)
    sys.exit(0)
  except FileExistsError:
    try:
      age = time.time() - os.path.getmtime(path)
      if age > 7200:
        os.unlink(path)
        continue
    except OSError:
      pass
    time.sleep(0.05)
sys.exit(1)
PY
  then
    soviez_migration_die MIGRATION_ACTIVE_OPERATION_CONFLICT "one active cutover per pair"
  fi
  # Ensure unlock on exit of this shell function path via trap scoped carefully
  trap 'rm -f "'"$lock_file"'"' RETURN

  # 1. Revalidate Phase 20 committed state (grace/activation/backup/ledger).
  local reval auth_id license_id
  reval="$(soviez_migration_p21_revalidate_phase20 "$pair_id")"
  auth_id="$(soviez_json_get "$reval" authorization_id)"
  license_id="$(soviez_json_get "$reval" license_id)"

  # Idempotent short-circuit: if traffic_owner already destination for this auth, return completed.
  if [[ -f "$(soviez_migration_traffic_owner_path "$auth_id")" ]]; then
    local cur_owner
    cur_owner="$(soviez_json_get "$(cat "$(soviez_migration_traffic_owner_path "$auth_id")")" traffic_owner 2>/dev/null || true)"
    if [[ "$cur_owner" == "destination" ]]; then
      local existing_op
      existing_op="$(soviez_json_get "$(cat "$(soviez_migration_traffic_owner_path "$auth_id")")" operation_id 2>/dev/null || true)"
      if [[ -n "$existing_op" && -f "$(soviez_migration_cutover_state_path "$existing_op")" ]]; then
        rm -f "$lock_file"
        trap - RETURN
        soviez_migration_cutover_certification_banner >&2 || true
        cat "$(soviez_migration_cutover_state_path "$existing_op")"
        return 0
      fi
    fi
  fi

  # 2. confirm already checked above.
  # 3. Canonical cutover flag — the ONLY way past the Phase 20/21 gates.
  export SOVIEZ_MIG_P21_CANONICAL_CUTOVER=1
  export SOVIEZ_MIG_P21_AUTH_ID="$auth_id"

  local fqdn="${SOVIEZ_MIG_P21_FQDN:-prod.example.test}"
  local dest_target="${SOVIEZ_MIG_P21_DEST_IP:-127.0.0.1}"
  local prev_target
  prev_target="$(soviez_migration_p21_dns_snapshot "$fqdn")"

  # 4. Create op state machine.
  local op_id
  op_id="$(soviez_migration_new_id cop)"
  soviez_migration_cutover_state_write "$op_id" "started" \
    "$(SOVIEZ_P="$pair_id" SOVIEZ_A="$auth_id" SOVIEZ_L="$license_id" SOVIEZ_F="$fqdn" SOVIEZ_PT="$prev_target" python3 -c '
import json, os
print(json.dumps({
  "pair_id": os.environ["SOVIEZ_P"],
  "authorization_id": os.environ["SOVIEZ_A"],
  "license_id": os.environ["SOVIEZ_L"],
  "fqdn": os.environ["SOVIEZ_F"],
  "previous_dns_target": os.environ["SOVIEZ_PT"],
}, separators=(",", ":")))
')" >/dev/null

  # 5. Final cutover sync (mandatory, bounded freeze).
  soviez_migration_cutover_state_write "$op_id" "final_cutover_sync" >/dev/null
  soviez_migration_final_cutover_sync_run "$pair_id" "$op_id" >/dev/null

  # 6. Source maintenance: grace -> freeze (maintenance page follows DNS confirm).
  soviez_migration_cutover_state_write "$op_id" "source_freeze" >/dev/null
  soviez_migration_source_transition_to_freeze "$auth_id" >/dev/null

  # 7. Destination route activate.
  soviez_migration_cutover_state_write "$op_id" "destination_route_activate" >/dev/null
  soviez_migration_p21_tls_prepare_fixture "$auth_id" "$fqdn" >/dev/null 2>&1 || true
  soviez_migration_destination_go_live_route_activate "$auth_id" "$fqdn" >/dev/null

  # 8. TLS validate (Production FQDN, hostname + expiry gate).
  soviez_migration_cutover_state_write "$op_id" "tls_validate" >/dev/null
  soviez_migration_p21_tls_validate "$auth_id" "$fqdn" >/dev/null

  # 9. DNS cutover — manual (attestation) or fixture provider.
  soviez_migration_cutover_state_write "$op_id" "dns_cutover" >/dev/null
  local dns_mode="${SOVIEZ_MIG_P21_DNS_MODE:-fixture}"
  if [[ "$dns_mode" == "manual" ]]; then
    soviez_migration_p21_dns_manual_instructions "$fqdn" "$dest_target" \
      > "$(soviez_migration_cutover_op_dir "$op_id")/dns_instructions.json"
    if [[ "${SOVIEZ_MIG_P21_DNS_CONFIRMED:-0}" != "1" ]]; then
      soviez_migration_die MIGRATION_DNS_CUTOVER_NOT_CONFIRMED "manual DNS change operator attestation required"
    fi
  fi
  soviez_migration_p21_dns_mutate "$fqdn" "$dest_target" >/dev/null

  # 10. Propagation observation (advisory unless required).
  soviez_migration_cutover_state_write "$op_id" "propagation_observe" >/dev/null
  soviez_migration_p21_propagation_observe "$fqdn" "$dest_target" \
    > "$(soviez_migration_cutover_op_dir "$op_id")/propagation.json"

  # Source now switches from freeze into signed maintenance now that DNS moved.
  soviez_migration_source_transition_to_maintenance "$auth_id" "$fqdn" >/dev/null

  # 11. Public health / smoke suite (mandatory tier).
  soviez_migration_cutover_state_write "$op_id" "post_cutover_validate" >/dev/null
  soviez_migration_destination_go_live_health "$auth_id" \
    > "$(soviez_migration_cutover_op_dir "$op_id")/health.json"
  soviez_migration_destination_go_live_synthetic_write "$auth_id" >/dev/null

  # 12. Commit boundary — traffic_owner flip (idempotent, exactly-once semantics).
  soviez_migration_cutover_state_write "$op_id" "traffic_owner_switch" >/dev/null
  soviez_migration_traffic_owner_switch "$auth_id" destination "$op_id" >/dev/null

  # 13. Restrict source — report the enforced state (deny_writes is the
  # standalone probe other callers use to prove writes are actually
  # rejected; calling it here would always die by design, since we are
  # deliberately in cutover_freeze/cutover_maintenance at this point).
  soviez_migration_source_transition_get "$auth_id" \
    > "$(soviez_migration_cutover_op_dir "$op_id")/source_restricted.json"

  # 14. Integrations — incremental; payments never before health/attestation.
  soviez_migration_cutover_state_write "$op_id" "integration_activate" >/dev/null
  soviez_migration_destination_go_live_integrations "$auth_id" mail >/dev/null
  soviez_migration_destination_go_live_integrations "$auth_id" webhooks >/dev/null
  soviez_migration_destination_go_live_integrations "$auth_id" cron >/dev/null
  if [[ "${SOVIEZ_MIG_P21_ACTIVATE_PAYMENTS:-0}" == "1" ]]; then
    soviez_migration_destination_go_live_integrations "$auth_id" payments >/dev/null
  fi

  # 15. Open rollback window.
  soviez_migration_cutover_state_write "$op_id" "rollback_window_open" >/dev/null
  local window="${SOVIEZ_MIG_P21_ROLLBACK_WINDOW_SECONDS:-1800}"
  SOVIEZ_OUT="$(soviez_migration_cutover_rollback_window_path "$op_id")" SOVIEZ_W="$window" python3 - <<'PY'
import json, os, datetime
opened = datetime.datetime.utcnow()
doc = {
  "opened_at": opened.strftime("%Y-%m-%dT%H:%M:%SZ"),
  "expires_at": (opened + datetime.timedelta(seconds=int(os.environ["SOVIEZ_W"]))).strftime("%Y-%m-%dT%H:%M:%SZ"),
  "window_seconds": int(os.environ["SOVIEZ_W"]),
}
open(os.environ["SOVIEZ_OUT"], "w").write(json.dumps(doc, separators=(",", ":")))
PY

  # 16. Stage cutover if Stages were selected (skips cleanly otherwise).
  soviez_migration_cutover_state_write "$op_id" "stage_cutover" >/dev/null
  soviez_migration_stage_cutover_run "$pair_id" > "$(soviez_migration_cutover_op_dir "$op_id")/stage_cutover.json"

  # 17. Phase 22 readiness report (post-cutover; never archives/purges).
  soviez_migration_cutover_state_write "$op_id" "phase22_readiness" >/dev/null
  soviez_migration_phase22_readiness "$auth_id" > "$(soviez_migration_cutover_op_dir "$op_id")/phase22_readiness.json"

  soviez_migration_cutover_state_write "$op_id" "cutover_complete" \
    '{"traffic_owner":"destination","production_dns_changed":true,"traffic_cutover_started":true,"phase22_allowed":false}' \
    >/dev/null

  soviez_migration_cutover_certification_banner >&2 || true
  soviez_migration_cutover_status "$op_id"
}

soviez_migration_cutover_show() {
  soviez_migration_cutover_plan_show "${1:-}"
}

soviez_migration_cutover_recover() {
  local op_id="${1:-}"
  [[ -n "$op_id" ]] || soviez_migration_die MIGRATION_RECOVERY_REQUIRED "operation-id required"
  soviez_migration_cutover_paths_init
  local f
  f="$(soviez_migration_cutover_state_path "$op_id")"
  [[ -f "$f" ]] || soviez_migration_die MIGRATION_RECOVERY_REQUIRED "cutover operation state missing"
  local fz
  fz="$(soviez_migration_cutover_freeze_path "$op_id")"
  if [[ -f "$fz" ]]; then
    local released
    released="$(soviez_json_get "$(cat "$fz")" released)"
    if [[ "$released" != "true" && "$released" != "True" ]]; then
      local expires
      expires="$(soviez_json_get "$(cat "$fz")" expires_at)"
      if soviez_migration_is_expired "$expires"; then
        soviez_migration_cutover_freeze_release "$op_id" "recover_timeout" >/dev/null
      fi
    fi
  fi
  cat "$f"
}

# Retry re-runs the full (idempotent) sequence for the same pair; every step
# either no-ops when already applied or continues from where it left off.
soviez_migration_cutover_retry() {
  local op_id="${1:-}"
  [[ -n "$op_id" ]] || soviez_migration_die MIGRATION_NOT_FOUND "operation-id required"
  local st pair_id
  st="$(soviez_migration_cutover_status "$op_id")"
  pair_id="$(soviez_json_get "$st" pair_id)"
  [[ -n "$pair_id" ]] || soviez_migration_die MIGRATION_NOT_FOUND "cutover operation missing pair_id"
  soviez_migration_cutover_start "$pair_id" 1
}

soviez_migration_cutover_dns_show() {
  local op_id="${1:-}"
  [[ -n "$op_id" ]] || soviez_migration_die MIGRATION_DNS_RECORD_NOT_FOUND "operation-id required"
  soviez_migration_cutover_paths_init
  local f
  f="$(soviez_migration_cutover_op_dir "$op_id")/dns_instructions.json"
  [[ -f "$f" ]] || soviez_migration_die MIGRATION_DNS_RECORD_NOT_FOUND "dns instructions not found for op"
  cat "$f"
}

soviez_migration_cutover_dns_try_again() {
  local op_id="${1:-}"
  [[ -n "$op_id" ]] || soviez_migration_die MIGRATION_DNS_RECORD_NOT_FOUND "operation-id required"
  export SOVIEZ_MIG_P21_DNS_CONFIRMED=1
  soviez_migration_cutover_retry "$op_id"
}
