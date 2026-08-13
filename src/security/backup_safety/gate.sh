# shellcheck shell=bash
# Security Gate S5 — backup safety gate + CLI commands.

soviez_security_validate_backup_safety() {
  local backup_dir="${1:-${SOVIEZ_S5_BACKUP_DIR:-}}"
  local dest="${2:-${SOVIEZ_BACKUP_DEST:-${SOVIEZ_S5_BACKUP_DEST:-local}}}"
  local op_id="${SOVIEZ_S5_OP_ID:-s5-backup-$(date -u +%Y%m%dT%H%M%SZ)-$$}"

  local evid
  if declare -F soviez_s5_op_dir >/dev/null 2>&1; then
    evid="$(soviez_s5_op_dir "$op_id")"
  else
    evid="${SOVIEZ_SEC_S5_EVIDENCE_ROOT:-${TMPDIR:-/tmp}/soviez-s5-evidence}/${op_id}"
    mkdir -p "$evid"/{checks,reports}
  fi

  local class dr_capable integrity secrets cipher disk overall="PASS"
  class="$(soviez_s5_backup_classify_destination "$dest")"
  dr_capable="$(soviez_s5_backup_dr_capable "$class" 2>/dev/null || echo false)"

  integrity="SKIP"
  if [[ -n "$backup_dir" && -d "$backup_dir" ]]; then
    integrity="$(soviez_s5_backup_integrity_verify "$backup_dir" 2>/dev/null)" || integrity="FAIL"
    [[ -n "$integrity" ]] || integrity="FAIL"
    secrets="$(soviez_s5_backup_secret_scan "$backup_dir" 2>/dev/null)" || secrets="UNNECESSARY"
    [[ -n "$secrets" ]] || secrets="UNNECESSARY"
    # Ciphertext check on first dump-like artifact if present.
    local sample=""
    sample="$(find "$backup_dir" -maxdepth 1 -type f \( -name '*.enc' -o -name 'db.dump*' -o -name '*.sql' \) 2>/dev/null | head -n1 || true)"
    if [[ -n "$sample" ]]; then
      cipher="$(soviez_s5_backup_assert_ciphertext "$sample" 2>/dev/null)" || cipher="FAIL"
      [[ -n "$cipher" ]] || cipher="FAIL"
    else
      cipher="SKIP"
    fi
  else
    secrets="SKIP"
    cipher="SKIP"
    if [[ "${SOVIEZ_S5_REQUIRE_BACKUP_DIR:-0}" == "1" ]]; then
      integrity="FAIL"
    fi
  fi

  local need_kb="${SOVIEZ_S5_BACKUP_NEED_KB:-0}"
  disk="$(soviez_s5_disk_preflight "$need_kb" 2>/dev/null)" || disk="FAIL"
  [[ -n "$disk" ]] || disk="FAIL"

  local restore="SKIP"
  if [[ "${SOVIEZ_S5_RUN_RESTORE_VERIFY:-0}" == "1" ]]; then
    restore="$(soviez_s5_restore_verify "${backup_dir:-$dest}" "${SOVIEZ_S5_RESTORE_TRUST:-EXTERNAL_UNKNOWN}" 2>/dev/null)" || restore="FAIL"
    [[ -n "$restore" ]] || restore="FAIL"
  fi

  # LOCAL_ONLY must never be reported as DR-complete.
  local dr_claim="OK"
  if [[ "$class" == "LOCAL_ONLY" && "${SOVIEZ_S5_CLAIM_DR:-0}" == "1" ]]; then
    dr_claim="FAIL"
  fi

  if [[ "$integrity" == "FAIL" || "$disk" == "FAIL" || "$cipher" == "FAIL" \
    || "$restore" == "FAIL" || "$dr_claim" == "FAIL" || "$secrets" == "UNNECESSARY" ]]; then
    overall="FAIL"
  fi

  python3 - "$evid/checks/backup_validation.json" \
    "$class" "$dr_capable" "$integrity" "$secrets" "$cipher" "$disk" "$restore" "$dr_claim" "$overall" <<'PY'
import json,sys
path=sys.argv[1]
keys=["destination_class","dr_capable","integrity","secret_scan","ciphertext","disk","restore_verify","dr_claim","overall"]
vals=sys.argv[2:]
# Normalize booleans
obj={"checks":dict(zip(keys,vals)),"overall":vals[-1],
     "local_only_is_not_dr": True}
json.dump(obj, open(path,"w"), indent=2)
PY

  soviez_s5_backup_report_write "$evid" "$overall" >/dev/null

  if [[ "$overall" == "PASS" ]]; then
    echo "[security] SEC_OK_BACKUP_SAFETY" >&2
    echo "$overall"
    return 0
  fi
  echo "[security] SEC_HIGH_BACKUP_SAFETY_FAILED (${overall})" >&2
  echo "$overall"
  return 1
}

soviez_cmd_security_backup_check() {
  export SOVIEZ_TEST_MODE="${SOVIEZ_TEST_MODE:-0}"
  local dir="${SOVIEZ_CLI_S5_BACKUP_DIR:-${SOVIEZ_S5_BACKUP_DIR:-}}"
  local dest="${SOVIEZ_CLI_S5_BACKUP_DEST:-${SOVIEZ_BACKUP_DEST:-local}}"
  local result
  result="$(soviez_security_validate_backup_safety "$dir" "$dest")"
  local rc=$?
  echo "overall=${result}"
  echo "class=$(soviez_s5_backup_classify_destination "$dest")"
  echo "dr_capable=$(soviez_s5_backup_dr_capable "$(soviez_s5_backup_classify_destination "$dest")" 2>/dev/null || echo false)"
  return "$rc"
}

soviez_cmd_security_backup_retention() {
  soviez_s5_backup_retention_cleanup "${SOVIEZ_CLI_S5_BACKUP_ROOT:-}"
  echo "retention=OK"
}
