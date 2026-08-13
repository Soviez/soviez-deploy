#!/usr/bin/env bash
# Phase 20 authorization / activation disposable fixtures.
# shellcheck shell=bash
# Requires dist/soviez.sh sourced before calling soviez_phase20_fixture_init.

soviez_phase20_fixture_init() {
  local repo_root="${1:-}"
  local multi_tenant="${2:-0}"

  if [[ -z "$repo_root" ]]; then
    repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  fi

  export SOVIEZ_TEST_MODE=1
  export SOVIEZ_MIG_ASSUME_YES=1
  export SOVIEZ_MIG_P20_FIXTURE_READY=1
  export SOVIEZ_SH_ROOT="$repo_root"

  SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p20-fixture.XXXXXX")"
  export SOVIEZ_ROOT
  unset SOVIEZ_MIG_P20_LEDGER_PATH SOVIEZ_MIG_P20_AUTH_ID SOVIEZ_MIG_P20_INJECT_DRIFT \
    SOVIEZ_MIG_P20_INJECT_SPLIT_BRAIN SOVIEZ_MIG_P20_INJECT_GRACE_FAIL SOVIEZ_MIG_P20_INJECT_LG_DENY \
    SOVIEZ_MIG_P20_STAGE_IDS SOVIEZ_MIG_P20_MANDATORY_STAGES SOVIEZ_MIG_LEGACY_CONSUME 2>/dev/null || true

  soviez_paths_init
  soviez_migration_paths_init
  soviez_migration_p20_paths_init

  export SOVIEZ_MIG_P20_ACCOUNT_ID="${SOVIEZ_MIG_P20_ACCOUNT_ID:-acct-p20}"
  export SOVIEZ_MIG_P20_LICENSE_ID="${SOVIEZ_MIG_P20_LICENSE_ID:-lic-p20}"
  export SOVIEZ_MIG_P20_SOURCE_FP="${SOVIEZ_MIG_P20_SOURCE_FP:-fp-source}"
  export SOVIEZ_MIG_P20_DEST_FP="${SOVIEZ_MIG_P20_DEST_FP:-fp-dest}"
  export SOVIEZ_MIG_P20_LOCAL_DEST_FP="${SOVIEZ_MIG_P20_LOCAL_DEST_FP:-fp-dest}"
  export SOVIEZ_MIG_P20_SOURCE_DB="${SOVIEZ_MIG_P20_SOURCE_DB:-aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa}"
  export SOVIEZ_MIG_P20_DEST_DB="${SOVIEZ_MIG_P20_DEST_DB:-bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb}"
  export SOVIEZ_MIG_P20_SOURCE_DIGEST="${SOVIEZ_MIG_P20_SOURCE_DIGEST:-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}"
  export SOVIEZ_MIG_P20_DEST_DIGEST="${SOVIEZ_MIG_P20_DEST_DIGEST:-sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb}"
  export SOVIEZ_MIG_P20_SOURCE_PROD="${SOVIEZ_MIG_P20_SOURCE_PROD:-prod-p20}"
  export SOVIEZ_MIG_P20_DEST_ENV="${SOVIEZ_MIG_P20_DEST_ENV:-dest-p20}"
  export SOVIEZ_MIG_P20_STAGING_ID="${SOVIEZ_MIG_P20_STAGING_ID:-staging-fixture}"
  unset SOVIEZ_MIG_P20_IDEMPOTENCY_KEY 2>/dev/null || true
  export SOVIEZ_MIG_P20_IDEMPOTENCY_KEY="${SOVIEZ_MIG_P20_IDEMPOTENCY_KEY:-idem-p20-$RANDOM-$$}"

  soviez_migration_p20_ledger seed \
    --account-id "$SOVIEZ_MIG_P20_ACCOUNT_ID" \
    --license-id "$SOVIEZ_MIG_P20_LICENSE_ID" \
    --grant-id grant-p20 \
    --credits 1 \
    --source-fp "$SOVIEZ_MIG_P20_SOURCE_FP" \
    --source-db-uuid "$SOVIEZ_MIG_P20_SOURCE_DB" \
    --source-digest "$SOVIEZ_MIG_P20_SOURCE_DIGEST" >/dev/null

  PAIR_ID="${PAIR_ID:-pair-p20-1}"
  export PAIR_ID
  mkdir -p "$(soviez_migration_pair_dir "$PAIR_ID")"
  SOVIEZ_PAIR="$PAIR_ID" python3 - <<PY
import json, os
pair_id = os.environ["SOVIEZ_PAIR"]
path = "$(soviez_migration_pair_dir "$PAIR_ID")/object.json"
open(path, "w").write(json.dumps({
  "schema": "soviez.migration_pair.v1",
  "migration_pair_id": pair_id,
  "license_id": os.environ["SOVIEZ_MIG_P20_LICENSE_ID"],
  "source_production_id": os.environ["SOVIEZ_MIG_P20_SOURCE_PROD"],
}, separators=(",", ":")))
PY

  if [[ "$multi_tenant" == "multi" || "$multi_tenant" == "1" || "${SOVIEZ_MIG_P20_SEED_MULTI:-0}" == "1" ]]; then
    soviez_migration_p20_ledger seed \
      --account-id acct-b \
      --license-id lic-b \
      --grant-id grant-b \
      --credits 1 \
      --source-fp fp-source-b \
      --source-db-uuid cccccccc-cccc-cccc-cccc-cccccccccccc \
      --source-digest sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc >/dev/null
  fi

  export SOVIEZ_MIG_P20_FIXTURE_READY_VAL="${SOVIEZ_MIG_P20_FIXTURE_READY_VAL:-PASS}"
}
