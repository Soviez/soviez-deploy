#!/usr/bin/env bash
# Phase 21 cutover disposable fixtures.
# shellcheck shell=bash
# Requires dist/soviez.sh sourced before calling soviez_phase21_fixture_init.

SOVIEZ_P21_FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/helpers/phase20_fixture.sh
source "$SOVIEZ_P21_FIXTURE_DIR/phase20_fixture.sh"

soviez_phase21_fixture_init() {
  local repo_root="${1:-}"
  local multi_tenant="${2:-}"

  if [[ -z "$repo_root" ]]; then
    repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  fi

  # 1. Phase 20 fixture init (seeds ledger, pair, license, fixture readiness).
  soviez_phase20_fixture_init "$repo_root" "$multi_tenant"

  # 2. Authorization commit + destination activate — establishes real Phase
  #    20 state (committed authorization, source grace, destination
  #    activation, verified backup) that Phase 21 revalidates before cutover.
  local receipt auth_id
  receipt="$(soviez_migration_authorization_commit "$PAIR_ID" 1)"
  auth_id="$(soviez_json_get "$receipt" authorization_id)"
  export SOVIEZ_MIG_P20_AUTH_ID="$auth_id"
  soviez_migration_destination_activate "$PAIR_ID" >/dev/null
  export SOVIEZ_MIG_P21_AUTH_ID="$auth_id"

  # 3. Phase 21 FQDN, DNS zone dir, fixture flags, cert dirs, nginx root.
  export SOVIEZ_MIG_P21_FIXTURE=1
  export SOVIEZ_MIG_P21_FQDN="${SOVIEZ_MIG_P21_FQDN:-prod.example.test}"
  export SOVIEZ_MIG_P21_DEST_IP="${SOVIEZ_MIG_P21_DEST_IP:-10.20.30.40}"
  export SOVIEZ_MIG_P21_DNS_ZONE_DIR="${SOVIEZ_MIG_P21_DNS_ZONE_DIR:-$SOVIEZ_ROOT/dns_zone}"
  export SOVIEZ_MIG_P21_NGINX_ROOT="${SOVIEZ_MIG_P21_NGINX_ROOT:-$SOVIEZ_ROOT/nginx_sites_p21}"
  export SOVIEZ_MIG_P21_ROLLBACK_WINDOW_SECONDS="${SOVIEZ_MIG_P21_ROLLBACK_WINDOW_SECONDS:-1800}"
  export SOVIEZ_MIG_P21_FREEZE_MAX_SECONDS="${SOVIEZ_MIG_P21_FREEZE_MAX_SECONDS:-900}"
  export SOVIEZ_MIG_TLS_ALLOW_SELF_SIGNED=1

  unset SOVIEZ_MIG_P21_CANONICAL_CUTOVER SOVIEZ_MIG_P21_INJECT_DRIFT SOVIEZ_MIG_P21_INJECT_HEALTH_FAIL \
    SOVIEZ_MIG_P21_INJECT_LOGIN_FAIL SOVIEZ_MIG_P21_INJECT_IPV6_FAIL SOVIEZ_MIG_P21_INJECT_SYNC_FAIL \
    SOVIEZ_MIG_P21_MEANINGFUL_WRITES SOVIEZ_MIG_P21_PAYMENT_CAPTURED SOVIEZ_MIG_P21_SPLIT_BRAIN \
    SOVIEZ_MIG_P21_HEALTH_FLAPPING SOVIEZ_MIG_P21_POST_WINDOW SOVIEZ_MIG_P21_DNS_MODE \
    SOVIEZ_MIG_P21_DNS_CONFIRMED SOVIEZ_MIG_P21_STAGE_IDS SOVIEZ_MIG_P21_STAGE_MANDATORY_IDS \
    SOVIEZ_MIG_P21_STAGE_FAIL_IDS SOVIEZ_MIG_P21_ACTIVATE_PAYMENTS SOVIEZ_MIG_P21_PAYMENTS_CHECKLIST_ATTESTED \
    SOVIEZ_MIG_P21_REQUIRE_REAL_TLS SOVIEZ_MIG_P21_REAL_FREEZE SOVIEZ_MIG_P21_READINESS_REPORT_ID 2>/dev/null || true

  mkdir -p "$SOVIEZ_MIG_P21_DNS_ZONE_DIR" "$SOVIEZ_MIG_P21_NGINX_ROOT"
}
