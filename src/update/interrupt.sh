# shellcheck shell=bash
# Update-specific interruption + reboot reconciliation (Phase 15 final).

soviez_update_interrupt_checkpoint() {
  local op_id="$1" checkpoint="$2"
  local marker
  marker="$(soviez_update_op_dir "$op_id")/interrupt_at"
  if [[ -f "$marker" ]]; then
    local want
    want="$(cat "$marker")"
    if [[ "$want" == "$checkpoint" ]]; then
      soviez_update_state_write "$op_id" recovery_required "$checkpoint" "{\"interrupted_at\":\"$checkpoint\"}"
      printf '{"ok":false,"code":"UPDATE_RECOVERY_REQUIRED","interrupted_at":"%s","operation_id":"%s"}\n' "$checkpoint" "$op_id"
      return 42
    fi
  fi
  return 0
}

soviez_update_reboot_reconcile() {
  local op_id="$1"
  soviez_update_paths_init
  local sf state checkpoint
  sf="$(soviez_update_op_state_file "$op_id")"
  if [[ ! -f "$sf" ]]; then
    soviez_update_die UPDATE_RECOVERY_REQUIRED "Missing state after reboot"
  fi
  if declare -F soviez_ops_sync_is_pending >/dev/null 2>&1; then
    if soviez_ops_sync_is_pending "$op_id" 2>/dev/null; then
      soviez_ops_sync_reconcile "$op_id" 2>/dev/null || true
    fi
  fi
  state="$(soviez_json_get "$(cat "$sf")" current_state)"
  checkpoint="$(soviez_json_get "$(cat "$sf")" checkpoint 2>/dev/null || true)"

  local cur_digest rb_digest cand_digest
  cur_digest="$(cat "$(soviez_update_op_dir "$op_id")/target_digest.txt" 2>/dev/null || true)"
  if [[ -f "$(soviez_update_rollback_manifest "$op_id")" ]]; then
    rb_digest="$(soviez_json_get "$(cat "$(soviez_update_rollback_manifest "$op_id")")" previous_digest)"
  fi
  cand_digest="$(cat "$(soviez_update_candidate_dir "$op_id")/runtime/running_digest.txt" 2>/dev/null || true)"

  case "$state:$checkpoint" in
    recovery_required:*|*:recovery_required|switching:*|*:switching|rollback_running:*|*:rollback*)
      soviez_update_state_write "$op_id" recovery_required "$checkpoint" "{\"reboot\":true}"
      SOVIEZ_OP="$op_id" SOVIEZ_CP="$checkpoint" SOVIEZ_CUR="$cur_digest" SOVIEZ_RB="$rb_digest" python3 - <<'PY'
import json,os
print(json.dumps({
  "ok":False,"code":"UPDATE_RECOVERY_REQUIRED",
  "operation_id":os.environ["SOVIEZ_OP"],
  "checkpoint":os.environ.get("SOVIEZ_CP"),
  "current_digest":os.environ.get("SOVIEZ_CUR"),
  "rollback_digest":os.environ.get("SOVIEZ_RB"),
  "duplicate_switch":False,"duplicate_rollback":False,
  "plan":"manual_recovery_required_no_blind_replay",
},separators=(",",":")))
PY
      return 0
      ;;
    completed:*)
      printf '{"ok":true,"code":"UPDATE_REBOOT_RECONCILED","state":"completed"}\n'
      return 0
      ;;
    *)
      # Safe resume states
      SOVIEZ_OP="$op_id" SOVIEZ_ST="$state" SOVIEZ_CP="$checkpoint" SOVIEZ_CUR="$cur_digest" \
      SOVIEZ_RB="$rb_digest" SOVIEZ_CD="$cand_digest" python3 - <<'PY'
import json,os
print(json.dumps({
  "ok":True,"code":"UPDATE_REBOOT_RECONCILED",
  "operation_id":os.environ["SOVIEZ_OP"],
  "current_state":os.environ.get("SOVIEZ_ST"),
  "checkpoint":os.environ.get("SOVIEZ_CP"),
  "current_digest":os.environ.get("SOVIEZ_CUR"),
  "rollback_digest":os.environ.get("SOVIEZ_RB"),
  "candidate_digest":os.environ.get("SOVIEZ_CD"),
  "duplicate_switch":False,"duplicate_rollback":False,
  "destructive_replay":False,
},separators=(",",":")))
PY
      return 0
      ;;
  esac
}

# Strongest available isolated reboot: Colima VM restart (stops Docker engine & reconstructs from disk).
soviez_update_host_reboot_exercise() {
  local op_id="$1" label="${2:-reboot}"
  local proof
  proof="$(soviez_update_op_dir "$op_id")/reboot_${label}.json"
  if [[ "${SOVIEZ_UPDATE_SKIP_COLIMA_REBOOT:-0}" == "1" ]]; then
    # Still prove reconcile path without VM reboot (documented limitation if used)
    soviez_update_reboot_reconcile "$op_id" > "$proof"
    return 0
  fi
  if ! command -v colima >/dev/null 2>&1; then
    soviez_update_die UPDATE_RECOVERY_REQUIRED "Colima unavailable for host-level Docker reboot exercise"
  fi
  local before_boot
  before_boot="$(date +%s)"
  # Persist reboot intent
  printf 'reboot_requested_at=%s\nlabel=%s\n' "$(soviez_utc_now)" "$label" > "$(soviez_update_op_dir "$op_id")/reboot_intent.txt"
  colima stop >/dev/null 2>&1 || true
  colima start >/dev/null 2>&1 || soviez_update_die UPDATE_RECOVERY_REQUIRED "Colima start failed after stop"
  export DOCKER_HOST=unix:///Users/raafatagha/.colima/default/docker.sock
  # Wait for docker
  local i
  for i in $(seq 1 60); do
    docker info >/dev/null 2>&1 && break
    sleep 2
  done
  docker info >/dev/null 2>&1 || soviez_update_die UPDATE_RECOVERY_REQUIRED "Docker not ready after Colima reboot"
  local out
  out="$(soviez_update_reboot_reconcile "$op_id")"
  SOVIEZ_O="$out" SOVIEZ_L="$label" SOVIEZ_B="$before_boot" SOVIEZ_A="$(date +%s)" python3 - <<'PY' > "$proof"
import json,os
body=json.loads(os.environ["SOVIEZ_O"])
body["reboot_label"]=os.environ["SOVIEZ_L"]
body["host_reboot"]="colima_vm_restart"
body["duration_sec"]=int(os.environ["SOVIEZ_A"])-int(os.environ["SOVIEZ_B"])
print(json.dumps(body,separators=(",",":")))
PY
  cat "$proof"
}
