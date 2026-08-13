# shellcheck shell=bash

SOVIEZ_IMAGE_CLEANUP_OP_TYPE=update_image_cleanup

SOVIEZ_IMAGE_CLEANUP_CODES=(
  IMAGE_CLEANUP_NOT_DUE
  IMAGE_CLEANUP_SAFETY_WINDOW_ACTIVE
  IMAGE_CLEANUP_CURRENT_IMAGE_PROTECTED
  IMAGE_CLEANUP_ROLLBACK_IMAGE_PROTECTED
  IMAGE_CLEANUP_IMAGE_IN_USE
  IMAGE_CLEANUP_STOPPED_CONTAINER_REFERENCE
  IMAGE_CLEANUP_PRODUCTION_REFERENCE
  IMAGE_CLEANUP_STAGE_REFERENCE
  IMAGE_CLEANUP_CANDIDATE_REFERENCE
  IMAGE_CLEANUP_ACTIVE_OPERATION_REFERENCE
  IMAGE_CLEANUP_RECOVERY_REFERENCE
  IMAGE_CLEANUP_OWNERSHIP_AMBIGUOUS
  IMAGE_CLEANUP_LABEL_MISSING
  IMAGE_CLEANUP_DIGEST_MISMATCH
  IMAGE_CLEANUP_SHARED_IMAGE_PROTECTED
  IMAGE_CLEANUP_DELETE_FAILED
  IMAGE_CLEANUP_PARTIAL
  IMAGE_CLEANUP_COMPLETED
  IMAGE_CLEANUP_NEEDS_ACTION
  DESTRUCTIVE_CONFIRMATION_REQUIRED
)

soviez_image_die() {
  local code="${1:-IMAGE_CLEANUP_NEEDS_ACTION}" message="${2:-Image cleanup failed}"
  soviez_log_error "${code}: ${message}"
  SOVIEZ_IMG_CODE="$code" SOVIEZ_IMG_MSG="$(soviez_redact_text "$message")" python3 - <<'PY' >&2
import json,os
print(json.dumps({"ok":False,"code":os.environ["SOVIEZ_IMG_CODE"],"message":os.environ["SOVIEZ_IMG_MSG"]},separators=(",",":")))
PY
  exit "${SOVIEZ_ERR_UPDATE:-23}"
}

soviez_image_forbid_prune_static_gate() {
  # Static gate: source and generated installer must not contain automated broad prune.
  local root="${SOVIEZ_SH_ROOT:-}"
  [[ -n "$root" ]] || root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd || pwd)"
  local hits
  hits="$(grep -RInE 'docker (system|image|container|volume|network|builder|buildx) prune' \
    "$root/src/update" "$root/src/commands" 2>/dev/null | grep -v 'FORBIDDEN\|forbid\|#.*prune\|never\|must not' || true)"
  if [[ -n "$hits" ]]; then
    soviez_image_die IMAGE_CLEANUP_DELETE_FAILED "Forbidden prune command present in update modules"
  fi
  # Also scan assembled dist if present
  if [[ -f "$root/dist/soviez.sh" ]]; then
    if grep -nE 'docker (system|image|container|volume|network|builder|buildx) prune' "$root/dist/soviez.sh" \
      | grep -v 'FORBIDDEN\|forbid\|never\|must not\|Static gate\|prune command' >/dev/null 2>&1; then
      # Allow documentation strings only — fail if executable prune line exists
      if grep -nE '^\s*docker (system|image|container|volume|network|builder|buildx) prune' "$root/dist/soviez.sh" >/dev/null 2>&1; then
        soviez_image_die IMAGE_CLEANUP_DELETE_FAILED "Forbidden prune executable line in dist/soviez.sh"
      fi
    fi
  fi
  printf '{"ok":true,"code":"FORBIDDEN_PRUNE_STATIC_GATE_PASS"}\n'
}
