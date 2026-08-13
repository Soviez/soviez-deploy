# shellcheck shell=bash
# Confirmation phrase: CLOSE ROLLBACK WINDOW <cutover-id>

soviez_migration_rollback_window_confirm() {
  local cutover_id="${1:-}"
  local expected phrase
  expected="CLOSE ROLLBACK WINDOW ${cutover_id}"
  phrase="${SOVIEZ_CLI_CONFIRM_PHRASE:-}"

  if [[ -z "$phrase" ]]; then
    if [[ -t 0 && "${SOVIEZ_MIG_P22_FIXTURE:-0}" != "1" ]]; then
      printf 'Type exact confirmation phrase to close rollback window:\n' >&2
      printf '  %s\n' "$expected" >&2
      read -r phrase
    else
      soviez_migration_die MIGRATION_PHASE22_CONFIRMATION_REQUIRED \
        "non-TTY requires --confirm-phrase \"$expected\""
    fi
  fi

  [[ "$phrase" == "$expected" ]] || \
    soviez_migration_die MIGRATION_PHASE22_CONFIRMATION_REQUIRED \
      "confirmation phrase mismatch (expected CLOSE ROLLBACK WINDOW <cutover-id>)"
  return 0
}
