#!/usr/bin/env bash
# Phase 23 authoritative certification aggregator.
# Runs focused cert suites + tests/run_all.sh + evidence finalizer.
# Aggregate exit must be 0 for PASS. Preserves prior failed-run logs.
set -euo pipefail
SH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVID="$SH_ROOT/docs/evidence/phase-23-offline-update-bundles"
mkdir -p "$EVID"
LOG="$EVID/AUTHORITATIVE_RUN_ALL.md"
CLEAN="$EVID/CLEAN_RUN_HISTORY.md"
RUN_LOG="/tmp/soviez-phase23-auth-run-all.log"
FOCUSED_LOG="/tmp/soviez-phase23-auth-focused.log"
export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH:-/usr/bin:/bin}"
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
export SOVIEZ_OPENSSL="${SOVIEZ_OPENSSL:-/opt/homebrew/bin/openssl}"

# shellcheck source=/dev/null
source "$SH_ROOT/tests/helpers/phase23_cert.sh"
soviez_phase23_cert_env
soviez_phase23_assert_cert_gates

{
  echo "# AUTHORITATIVE_RUN_ALL"
  echo
  echo "Started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "DOCKER_HOST=$DOCKER_HOST"
  echo "SOVIEZ_PHASE23_CERTIFICATION=1"
  echo "Installer candidate: 0.23.0-phase23"
  echo
} > "$LOG"

fail=0
focused_ok=0
focused_fail=0

echo "==> environment preflight"
if ! soviez_phase23_docker_preflight; then
  echo "DOCKER_PREFLIGHT_FAIL" | tee -a "$LOG"
  echo "phase23_authoritative_certification=FAIL aggregate_exit_code=1"
  exit 1
fi
if ! soviez_phase23_postgres_preflight; then
  echo "POSTGRES_PREFLIGHT_FAIL" | tee -a "$LOG"
  echo "phase23_authoritative_certification=FAIL aggregate_exit_code=1"
  exit 1
fi
soviez_phase23_exact_fixture_reset
soviez_phase23_erp_fixture_ensure || {
  echo "ERP_FIXTURE_FAIL" | tee -a "$LOG"
  echo "phase23_authoritative_certification=FAIL aggregate_exit_code=1"
  exit 1
}
soviez_phase23_environment_preflight_report "$EVID/ENVIRONMENT_PREFLIGHT.md"

run_focused() {
  local t="$1"
  [[ -f "$t" ]] || return 0
  echo "==> focused $t"
  set +e
  bash "$t" >>"$FOCUSED_LOG" 2>&1
  local rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    echo "OK $t" | tee -a "$LOG"
    focused_ok=$((focused_ok + 1))
  else
    echo "FAIL $t (rc=$rc)" | tee -a "$LOG"
    tail -n 40 "$FOCUSED_LOG" | sed 's/^/    /' >> "$LOG" || true
    focused_fail=$((focused_fail + 1))
    fail=1
  fi
}

: > "$FOCUSED_LOG"
echo "==> Phase 23 focused certification suites"
# Reboot suite runs deferred inside tests/run_all.sh (filename match) AFTER other
# Docker-dependent suites, with deny-proxy cleared before colima restart.
for t in \
  tests/unit/test_phase23_docker_preflight.sh \
  tests/unit/test_phase23_postgres_preflight.sh \
  tests/unit/test_phase23_exact_fixture_reset.sh \
  tests/unit/test_phase23_failure_classification.sh \
  tests/unit/test_phase23_evidence_finalizer.sh \
  tests/unit/test_phase23_offline_bundle_unit.sh \
  tests/integration/test_phase23_real_registry_oci.sh \
  tests/integration/test_phase23_real_ed25519.sh \
  tests/integration/test_phase23_real_airgapped_apply.sh \
  tests/integration/test_phase23_offline_bundle_integration.sh \
  tests/integration/test_phase23_saas_schema_upgrade.sh \
  tests/integration/test_phase23_saas_typecheck_lint_build.sh \
  tests/security/test_phase23_offline_bundle_security.sh
do
  run_focused "$SH_ROOT/$t"
done

# Clear any residual deny-proxies from air-gap focused suites before run_all.
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy \
  SOVIEZ_OFFLINE_APPLY_NETWORK_DENIED 2>/dev/null || true

echo "==> tests/run_all.sh"
# Ensure deny-proxies from prior focused air-gap/reboot work do not poison Docker pulls.
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy \
  SOVIEZ_OFFLINE_APPLY_NETWORK_DENIED 2>/dev/null || true
export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH:-/usr/bin:/bin}"
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
export SOVIEZ_OPENSSL="${SOVIEZ_OPENSSL:-/opt/homebrew/bin/openssl}"
set +e
bash "$SH_ROOT/tests/run_all.sh" 2>&1 | tee "$RUN_LOG"
rc_all=$?
set -e
# grep -c prints 0 but exits 1 when there are no matches; do not append a second
# "0" via `|| echo 0` (that produced fail_count=$'0\n0' and broke the finalizer).
ok_count="$(grep -c '^OK tests/' "$RUN_LOG" 2>/dev/null || true)"
fail_count="$(grep -c '^FAIL tests/' "$RUN_LOG" 2>/dev/null || true)"
ok_count="${ok_count:-0}"
fail_count="${fail_count:-0}"
{
  echo "## tests/run_all.sh"
  echo "exit_code: $rc_all"
  echo "ok_count: $ok_count"
  echo "fail_count: $fail_count"
  echo "focused_ok: $focused_ok"
  echo "focused_fail: $focused_fail"
  tail -n 60 "$RUN_LOG" | sed 's/^/    /'
  echo
} >> "$LOG"
[[ $rc_all -eq 0 ]] || fail=1

# Assemble ensures artifact exists; compute SHA
bash "$SH_ROOT/build/assemble.sh" >/dev/null
ART="$SH_ROOT/dist/soviez.sh"
VER="0.23.0-phase23"

LEDGER="$EVID/PRIOR_FAILURE_LEDGER.md"
AUTH_EXIT=$fail
[[ $fail -eq 0 ]] || AUTH_EXIT=1

echo "==> evidence finalizer"
set +e
python3 "$SH_ROOT/scripts/phase23_evidence_finalizer.py" \
  --evidence-dir "$EVID" \
  --run-all-exit "$rc_all" \
  --auth-exit "$AUTH_EXIT" \
  --artifact "$ART" \
  --version "$VER" \
  --ok-count "$ok_count" \
  --fail-count "$fail_count" \
  --ledger "$LEDGER" \
  --prior-log /tmp/soviez-run-all-p23.log \
  --prior-log /tmp/soviez-run-all-p23b.log \
  --prior-log "$RUN_LOG" \
  --prior-log "$FOCUSED_LOG"
fin_rc=$?
set -e
{
  echo "## evidence_finalizer"
  echo "exit_code: $fin_rc"
  echo
} >> "$LOG"

AGG=0
OVERALL=PASS
if [[ $fail -ne 0 || $rc_all -ne 0 || $fin_rc -ne 0 ]]; then
  OVERALL=FAIL
  AGG=1
fi

{
  echo "## Aggregate"
  echo "phase23_authoritative_certification: $OVERALL"
  echo "aggregate_exit_code: $AGG"
  echo "Finished: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} >> "$LOG"

{
  echo "# CLEAN_RUN_HISTORY"
  echo
  echo "- prior: /tmp/soviez-run-all-p23.log (FAILED — LibreSSL ED25519)"
  echo "- prior: /tmp/soviez-run-all-p23b.log (FAILED — ENOSPC/rg cascade)"
  echo "- this run: $RUN_LOG (run_all exit=$rc_all)"
  echo "- focused: $FOCUSED_LOG (focused_fail=$focused_fail)"
  echo "- authoritative: $OVERALL aggregate=$AGG $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$CLEAN"

echo "phase23_authoritative_certification=$OVERALL aggregate_exit_code=$AGG"
exit "$AGG"
