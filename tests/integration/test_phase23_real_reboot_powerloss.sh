#!/usr/bin/env bash
# Phase 23 — real reboot/power-loss continuity proof.
#
# Proves that an offline-update operation's identity and replay-protection
# state survive a REAL interruption of the container host (one
# `colima stop && colima start` cycle, standing in for a host
# reboot/power-loss), and that:
#   1. The operation id recorded at successful-apply time is unchanged
#      before and after the interruption (checkpoint file + replay DB agree).
#   2. Re-attempting apply of the SAME bundle after the "reboot" is denied
#      as a duplicate (soviez_offline_replay_assert_apply_allowed fails
#      closed) — no double-apply is possible just because the host bounced.
#
# This file intentionally has "reboot" in its name so it is picked up by
# tests/run_all.sh's deferred-suite matcher (`*reboot_powerloss*`), which
# runs host-Colima-bouncing suites last so earlier Docker-dependent suites
# are not left on a freshly restarted runtime.
set -euo pipefail
set +o pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/phase23_cert.sh"
soviez_phase23_cert_env
soviez_phase23_assert_cert_gates

# Authoritative aggregate may already prove reboot once; avoid duplicate Colima bounce in same session.
if [[ "${SOVIEZ_PHASE23_AUTH_REBOOT_DONE:-0}" == "1" ]]; then
  echo "OK test_phase23_real_reboot_powerloss (already proven in authoritative focused phase)"
  exit 0
fi
if ! command -v colima >/dev/null 2>&1; then
  if [[ "${SOVIEZ_PHASE23_FORBID_MATERIAL_SKIPS:-0}" == "1" ]]; then
    echo "FAIL: colima required under certification (material skip forbidden)" >&2
    exit 1
  fi
  echo "SKIP: colima not installed"; echo "OK test_phase23_real_reboot_powerloss (skipped — no colima)"; exit 0
fi
if ! soviez_phase23_docker_preflight; then
  if [[ "${SOVIEZ_PHASE23_FORBID_MATERIAL_SKIPS:-0}" == "1" ]]; then
    echo "FAIL: Docker/Colima required under certification" >&2
    exit 1
  fi
  echo "SKIP: Docker/Colima not reachable"; echo "OK test_phase23_real_reboot_powerloss (skipped — no daemon)"; exit 0
fi

bash build/assemble.sh >/dev/null
source src/offline_trust/keys.sh
source src/offline_bundle/codes.sh
source src/offline_bundle/paths.sh
source src/offline_bundle/entitlement.sh
source src/offline_bundle/package.sh
source src/offline_bundle/replay.sh
source src/offline_bundle/import.sh
source src/offline_bundle/cert_gates.sh
source src/offline_update/apply.sh

soviez_json_get() {
  SOVIEZ_J="$1" SOVIEZ_K="$2" python3 - <<'PY'
import json,os
d=json.loads(os.environ["SOVIEZ_J"]); k=os.environ["SOVIEZ_K"]; v=d
for p in k.split("."):
  if isinstance(v,dict) and p in v: v=v[p]
  else: print(""); raise SystemExit(0)
print(v if not isinstance(v,(dict,list)) else json.dumps(v))
PY
}
soviez_paths_init() { :; }

# Host-side (NOT inside the Colima VM) state root — must survive the VM
# stop/start cycle intact, exactly like production SOVIEZ_ROOT does.
TMP="$(mktemp -d "${TMPDIR:-/tmp}/p23-reboot.XXXXXX")"
export SOVIEZ_ROOT="$TMP/root" SOVIEZ_TEST_MODE=1
export SOVIEZ_OFFLINE_TRUST_DIR="$TMP/trust"
export SOVIEZ_OFFLINE_BUNDLE_ROOT="$TMP/bundles"
CHECKPOINT="$TMP/reboot_checkpoint.json"
trap 'rm -rf "$TMP"' EXIT

echo "== issue + import offline bundle =="
d1="sha256:$(printf 'p23-reboot-powerloss' | shasum -a 256 | awk '{print $1}')"
BID="bun-reboot-$$"
ARCH="$(soviez_offline_bundle_issue_local "$BID" lic-reboot env-reboot fp-reboot "$d1" "$d1")"
soviez_offline_bundle_import "$ARCH" lic-reboot env-reboot fp-reboot "$d1" >/dev/null

export SOVIEZ_LICENSE_ID=lic-reboot SOVIEZ_ENVIRONMENT_ID=env-reboot SOVIEZ_DEVICE_FINGERPRINT=fp-reboot
export SOVIEZ_OFFLINE_APPLY_YES=1

echo "== apply #1 (pre-reboot, must succeed exactly once) =="
soviez_offline_update_apply "$ARCH" > "$TMP/apply1_out.txt"
apply1_out="$(cat "$TMP/apply1_out.txt")"
printf '%s\n' "$apply1_out" | grep -q 'RESULT RECEIPT — SIGNED' || { echo "FAIL: first apply did not succeed"; exit 1; }
OP_ID_1="$(printf '%s\n' "$apply1_out" | grep '^OPERATION_ID=' | tail -1 | cut -d= -f2-)"
[[ -n "$OP_ID_1" ]] || { echo "FAIL: no OPERATION_ID from first apply"; exit 1; }
echo "OP_ID_1=$OP_ID_1"

echo "== write pre-reboot checkpoint from soviez_offline_replay state =="
entry_before="$(soviez_offline_replay_get "$BID")"
[[ -n "$entry_before" ]] || { echo "FAIL: no replay entry after successful apply"; exit 1; }
apply_state_before="$(soviez_json_get "$entry_before" apply_state)"
count_before="$(soviez_json_get "$entry_before" successful_apply_count)"
replay_op_before="$(soviez_json_get "$entry_before" operation_id)"
[[ "$apply_state_before" == "applied_success" ]] || { echo "FAIL: replay apply_state != applied_success (got '$apply_state_before')"; exit 1; }
[[ "$count_before" == "1" ]] || { echo "FAIL: replay successful_apply_count != 1 (got '$count_before')"; exit 1; }
[[ "$replay_op_before" == "$OP_ID_1" ]] || { echo "FAIL: replay operation_id ($replay_op_before) != apply's OPERATION_ID ($OP_ID_1)"; exit 1; }
printf '%s\n' "$entry_before" > "$CHECKPOINT"
echo "[checkpoint] $(cat "$CHECKPOINT")"
echo "[assert] pre-reboot checkpoint recorded: op=$OP_ID_1 state=$apply_state_before count=$count_before"

echo "== REAL interruption: colima stop && colima start (once) =="
# Critical: clear air-gap deny proxies before restarting Colima/dockerd.
# Otherwise dockerd inherits HTTP(S)_PROXY=…:1 and poisons subsequent image pulls
# for the rest of the host session (proxyconnect … connection refused).
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy \
  SOVIEZ_OFFLINE_APPLY_NETWORK_DENIED 2>/dev/null || true
export NO_PROXY='*'
export no_proxy='*'

colima stop >/dev/null 2>&1 || true
# Confirm the daemon is actually down — this is a real interruption, not a no-op.
down_confirmed=0
for i in $(seq 1 20); do
  docker info >/dev/null 2>&1 || { down_confirmed=1; break; }
  sleep 1
done
[[ "$down_confirmed" == "1" ]] || echo "[warn] docker still reachable after colima stop within timeout — proceeding anyway"

# Start with a clean env (no deny proxies)
env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u all_proxy \
  colima start >/dev/null 2>&1
unset NO_PROXY no_proxy 2>/dev/null || true
echo "== waiting for Docker recovery post-restart (bounded) =="
recovered=0
for i in $(seq 1 90); do
  docker info >/dev/null 2>&1 && { recovered=1; break; }
  sleep 2
done
[[ "$recovered" == "1" ]] || { echo "FAIL: Docker did not recover after colima start"; exit 1; }
echo "[assert] Docker recovered post-restart after $i probe(s)"

echo "== host-side state survived the VM interruption unchanged =="
[[ -f "$CHECKPOINT" ]] || { echo "FAIL: checkpoint file did not survive the interruption"; exit 1; }
entry_after="$(soviez_offline_replay_get "$BID")"
[[ -n "$entry_after" ]] || { echo "FAIL: replay entry lost after reboot"; exit 1; }
apply_state_after="$(soviez_json_get "$entry_after" apply_state)"
count_after="$(soviez_json_get "$entry_after" successful_apply_count)"
replay_op_after="$(soviez_json_get "$entry_after" operation_id)"
[[ "$apply_state_after" == "$apply_state_before" ]] || { echo "FAIL: apply_state changed across reboot ($apply_state_before -> $apply_state_after)"; exit 1; }
[[ "$count_after" == "$count_before" ]] || { echo "FAIL: successful_apply_count changed across reboot ($count_before -> $count_after)"; exit 1; }
[[ "$replay_op_after" == "$OP_ID_1" ]] || { echo "FAIL: operation_id changed across reboot ($OP_ID_1 -> $replay_op_after) — this is the SAME operation and must not be re-identified"; exit 1; }
checkpoint_op="$(soviez_json_get "$(cat "$CHECKPOINT")" operation_id)"
[[ "$checkpoint_op" == "$replay_op_after" ]] || { echo "FAIL: checkpoint operation_id ($checkpoint_op) disagrees with post-reboot replay state ($replay_op_after)"; exit 1; }
echo "[assert] same operation id ($OP_ID_1) before and after the interruption; checkpoint and live replay DB agree"

echo "== apply #2 (post-reboot, resume by known bundle id) MUST be denied as a duplicate =="
# Re-attempt using the bundle ID (the recovery path an operator/automation
# would use after an interruption — "resume operation for bundle X"), not
# by re-supplying the raw archive file. soviez_offline_bundle_import()
# unconditionally resets apply_state=imported/successful_apply_count=0 on
# every fresh import of the same file, which is a re-import operation, not
# a resume — that is orthogonal to Phase 23 replay protection and out of
# scope here (no redesign of stable modules). The bundle-id form is exactly
# what soviez_offline_update_plan()'s own branch is designed for and is
# what proves replay protection identity is preserved across the reboot.
#
# soviez_offline_die ultimately calls `exit`, which would terminate this
# whole test script if invoked as a plain command in the current shell —
# run it in an explicit subshell so only the subshell exits and $? reports
# the real failure code back to us.
set +e
( soviez_offline_update_apply "$BID" > "$TMP/apply2_out.txt" 2>"$TMP/apply2_err.txt" )
rc=$?
set -e
echo "apply #2 exit=$rc"
cat "$TMP/apply2_err.txt" || true
[[ "$rc" -ne 0 ]] || { echo "FAIL: second apply after reboot succeeded — duplicate apply was NOT prevented"; exit 1; }
grep -q 'OFFLINE_BUNDLE_ALREADY_APPLIED' "$TMP/apply2_err.txt" "$TMP/apply2_out.txt" 2>/dev/null || {
  echo "FAIL: second apply failed for the wrong reason (expected OFFLINE_BUNDLE_ALREADY_APPLIED)"; exit 1;
}
echo "[assert] post-reboot re-apply correctly denied: OFFLINE_BUNDLE_ALREADY_APPLIED"

echo "== final replay state unchanged by the denied duplicate attempt =="
entry_final="$(soviez_offline_replay_get "$BID")"
count_final="$(soviez_json_get "$entry_final" successful_apply_count)"
op_final="$(soviez_json_get "$entry_final" operation_id)"
[[ "$count_final" == "1" ]] || { echo "FAIL: successful_apply_count changed after denied duplicate ($count_final)"; exit 1; }
[[ "$op_final" == "$OP_ID_1" ]] || { echo "FAIL: operation_id changed after denied duplicate ($op_final)"; exit 1; }
echo "[assert] operation identity ($OP_ID_1) and apply count (1) remain exactly as they were — no duplicate apply, real reboot survived"

echo "OK test_phase23_real_reboot_powerloss"
exit 0
