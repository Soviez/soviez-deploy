# shellcheck shell=bash

soviez_migration_p20_ledger_bin() {
  local root="${SOVIEZ_SH_ROOT:-}"
  printf '%s\n' "$root/services/migration-authorization-ledger/ledger.py"
}

soviez_migration_p20_ledger() {
  local cmd="$1"; shift
  local bin
  bin="$(soviez_migration_p20_ledger_bin)"
  [[ -f "$bin" ]] || soviez_migration_die MIGRATION_AUTHORIZATION_REQUIRED "ledger.py missing"
  export SOVIEZ_MIG_P20_LEDGER_PATH="${SOVIEZ_MIG_P20_LEDGER_PATH:-$SOVIEZ_MIG_ROOT/p20_ledger.sqlite}"
  python3 "$bin" "$cmd" "$@"
}

soviez_migration_p20_auth_dir() {
  local id="$1"
  printf '%s\n' "$SOVIEZ_MIG_ROOT/authorization/$id"
}

soviez_migration_p20_paths_init() {
  soviez_migration_paths_init
  mkdir -p "$SOVIEZ_MIG_ROOT/authorization" "$SOVIEZ_MIG_ROOT/activation" \
    "$SOVIEZ_MIG_ROOT/grace" "$SOVIEZ_MIG_ROOT/phase21_readiness" \
    "$SOVIEZ_MIG_ROOT/offline_packages" "$SOVIEZ_MIG_ROOT/ops"
}
