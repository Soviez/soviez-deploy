#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Prefer Homebrew tools (rg, openssl@3) over macOS LibreSSL / missing rg.
export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH:-/usr/bin:/bin}"
# Provide `rg` for static security suites when ripgrep is not installed.
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/rg_fallback.sh"
# Optional Phase 23 fixture helpers (ERP labels / disk) when present.
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/phase23_cert.sh" 2>/dev/null || true
if declare -F soviez_phase23_erp_fixture_ensure >/dev/null 2>&1; then
  soviez_phase23_erp_fixture_ensure || true
fi

# Prevent inherited disposable-path pollution from parent shells.
unset SOVIEZ_ROOT SOVIEZ_OPS_ROOT SOVIEZ_STAGES_DIR SOVIEZ_STAGE_OPS_DIR \
  SOVIEZ_SSL_ROOT SOVIEZ_SSL_OPS_DIR SOVIEZ_SSL_INVENTORY_DIR SOVIEZ_OPS_REGISTRY_DIR \
  SOVIEZ_OPS_INDEX_DIR SOVIEZ_DEVICE_DIR SOVIEZ_SECRETS_DIR SOVIEZ_TENANT_DIR \
  SOVIEZ_RETENTION_INJECT_BACKUP_FAIL SOVIEZ_RETENTION_NOW_UTC \
  SOVIEZ_RETENTION_EXTEND_CONFIRM SOVIEZ_RETENTION_RUN_CONFIRM \
  SOVIEZ_RETENTION_INJECT_STOP_FAIL SOVIEZ_RETENTION_INJECT_NGINX_FAIL \
  SOVIEZ_UPDATE_REAL_DOCKER SOVIEZ_UPDATE_REAL_IMAGE SOVIEZ_UPDATE_CANDIDATE_HOST_ROOT \
  SOVIEZ_UPDATE_FIXTURE_ADDON_FAIL SOVIEZ_UPDATE_FIXTURE_UPGRADE_FAIL \
  SOVIEZ_UPDATE_FIXTURE_SWITCH_FAIL SOVIEZ_UPDATE_FIXTURE_POST_SWITCH_FAIL \
  SOVIEZ_UPDATE_SKIP_COLIMA_REBOOT SOVIEZ_IMAGE_CLEANUP_FORCE_WINDOW_ELAPSED \
  SOVIEZ_BACKUP_ROOT SOVIEZ_BACKUP_OPS_DIR SOVIEZ_BACKUP_DATA_DIR \
  SOVIEZ_BACKUP_PASSPHRASE SOVIEZ_BACKUP_DISABLE_ENCRYPTION \
  SOVIEZ_RESTORE_OPS_DIR SOVIEZ_RESTORE_CANDIDATES_DIR \
  SOVIEZ_PHASE19_CERTIFICATION SOVIEZ_PHASE19_REQUIRE_REAL_MTLS \
  SOVIEZ_PHASE19_REQUIRE_REAL_POSTGRES SOVIEZ_PHASE19_REQUIRE_REAL_ERP_STAGING \
  SOVIEZ_PHASE19_REQUIRE_REAL_STAGE SOVIEZ_PHASE19_REQUIRE_HOST_REBOOT \
  SOVIEZ_PHASE19_REQUIRE_NETWORK_INTERRUPTION SOVIEZ_PHASE19_FORBID_LOCAL_TRANSFER \
  SOVIEZ_PHASE19_FORBID_FIXTURE_ERP SOVIEZ_PHASE19_FORBID_FIXTURE_DB \
  SOVIEZ_MIG_TRANSFER_LOCAL SOVIEZ_MIG_FORCE_FIXTURE_ERP SOVIEZ_MIG_FORCE_FIXTURE_DB \
  SOVIEZ_MIG_FREEZE_FIXTURE SOVIEZ_MIG_REAL_ERP_STAGING SOVIEZ_P19_SKIP_COLIMA_REBOOT \
  SOVIEZ_P19_SKIP_NETWORK_INTERRUPTION SOVIEZ_BACKUP_SFTP_INTERRUPT SOVIEZ_BACKUP_S3_INTERRUPT \
  SOVIEZ_BACKUP_SFTP_REAL SOVIEZ_BACKUP_S3_REAL \
  SOVIEZ_PHASE22_CERTIFICATION SOVIEZ_PHASE22_REQUIRE_HOST_REBOOT \
  SOVIEZ_PHASE22_REQUIRE_NETWORK_INTERRUPTION SOVIEZ_PHASE22_REQUIRE_REAL_S3 \
  SOVIEZ_PHASE22_REQUIRE_REAL_SFTP SOVIEZ_PHASE22_SKIP_HOST_REBOOT \
  SOVIEZ_PHASE22_SKIP_NETWORK_INTERRUPTION SOVIEZ_PHASE22_SKIP_S3 SOVIEZ_PHASE22_SKIP_SFTP \
  SOVIEZ_PHASE22_ALLOW_REBOOT_SIM SOVIEZ_MIG_P22_ARCHIVE_S3_PROFILE \
  SOVIEZ_MIG_P22_ARCHIVE_SFTP_PROFILE SOVIEZ_MIG_P22_S3_INTERRUPT \
  SOVIEZ_MIG_P22_SFTP_INTERRUPT SOVIEZ_MIG_P22_ARCHIVE_LOST_ACK \
  SOVIEZ_MIG_P22_LICENSE_RESPONSE_LOSS SOVIEZ_MIG_P22_RUNTIME_RESPONSE_LOSS \
  SOVIEZ_PHASE23_CERTIFICATION SOVIEZ_PHASE23_REQUIRE_REAL_ED25519 \
  SOVIEZ_PHASE23_REQUIRE_REAL_OCI_EXPORT SOVIEZ_PHASE23_REQUIRE_REAL_PRIVATE_REGISTRY \
  SOVIEZ_PHASE23_REQUIRE_REAL_ARTIFACT_STORAGE SOVIEZ_PHASE23_REQUIRE_REAL_POSTGRES \
  SOVIEZ_PHASE23_REQUIRE_REAL_BACKUP SOVIEZ_PHASE23_REQUIRE_REAL_OFFLINE_APPLY \
  SOVIEZ_PHASE23_REQUIRE_NO_NETWORK_APPLY SOVIEZ_PHASE23_REQUIRE_REAL_REBOOT \
  SOVIEZ_PHASE23_REQUIRE_POWERLOSS_RECOVERY SOVIEZ_PHASE23_FORBID_FAKE_SIGNATURES \
  SOVIEZ_PHASE23_FORBID_MATERIAL_SKIPS SOVIEZ_PHASE23_FORBID_REGISTRY_CREDS_IN_BUNDLE \
  SOVIEZ_PHASE23_CERT_CLOCK_EPOCH SOVIEZ_OFFLINE_SOFT_DIE SOVIEZ_OPENSSL \
  SOVIEZ_OFFLINE_TRUST_DIR SOVIEZ_OFFLINE_BUNDLE_ROOT SOVIEZ_PHASE23_SIMULATE_FULL_ENGINE 2>/dev/null || true

export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"

# Clear air-gap / cert deny-proxy pollution so Docker pulls and SaaS fixtures work.
# Phase 23 offline-apply suites set http_proxy=127.0.0.1:1 in their own process;
# defense-in-depth: never inherit deny proxies into the aggregate runner.
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy \
  SOVIEZ_OFFLINE_APPLY_NETWORK_DENIED NO_PROXY no_proxy 2>/dev/null || true

# shellcheck source=/dev/null
source "$ROOT/tests/helpers/fixture_preflight_reset.sh"
soviez_fixture_preflight_reset

bash build/assemble.sh
bash -n dist/soviez.sh

chmod +x tests/helpers/*.sh tests/unit/*.sh tests/integration/*.sh tests/run_all.sh 2>/dev/null || true

fail=0
run_one() {
  local t="$1"
  [[ -f "$t" ]] || return 0
  # Ensure Phase 19 certification env never bleeds across suites (defense in depth).
  unset SOVIEZ_PHASE19_CERTIFICATION SOVIEZ_PHASE19_REQUIRE_REAL_MTLS \
    SOVIEZ_PHASE19_REQUIRE_REAL_POSTGRES SOVIEZ_PHASE19_REQUIRE_REAL_ERP_STAGING \
    SOVIEZ_PHASE19_REQUIRE_REAL_STAGE SOVIEZ_PHASE19_REQUIRE_HOST_REBOOT \
    SOVIEZ_PHASE19_REQUIRE_NETWORK_INTERRUPTION SOVIEZ_PHASE19_FORBID_LOCAL_TRANSFER \
    SOVIEZ_PHASE19_FORBID_FIXTURE_ERP SOVIEZ_PHASE19_FORBID_FIXTURE_DB \
    SOVIEZ_MIG_TRANSFER_LOCAL SOVIEZ_MIG_FORCE_FIXTURE_ERP SOVIEZ_MIG_FORCE_FIXTURE_DB \
    SOVIEZ_MIG_FREEZE_FIXTURE SOVIEZ_MIG_REAL_ERP_STAGING SOVIEZ_P19_SKIP_COLIMA_REBOOT \
    SOVIEZ_P19_SKIP_NETWORK_INTERRUPTION SOVIEZ_BACKUP_SFTP_INTERRUPT SOVIEZ_BACKUP_S3_INTERRUPT \
    SOVIEZ_BACKUP_SFTP_REAL SOVIEZ_BACKUP_S3_REAL \
    SOVIEZ_PHASE22_CERTIFICATION SOVIEZ_PHASE22_REQUIRE_HOST_REBOOT \
    SOVIEZ_PHASE22_REQUIRE_NETWORK_INTERRUPTION SOVIEZ_PHASE22_REQUIRE_REAL_S3 \
    SOVIEZ_PHASE22_REQUIRE_REAL_SFTP SOVIEZ_PHASE22_SKIP_HOST_REBOOT \
    SOVIEZ_PHASE22_SKIP_NETWORK_INTERRUPTION SOVIEZ_PHASE22_SKIP_S3 SOVIEZ_PHASE22_SKIP_SFTP \
    SOVIEZ_PHASE22_ALLOW_REBOOT_SIM SOVIEZ_MIG_P22_ARCHIVE_S3_PROFILE \
    SOVIEZ_MIG_P22_ARCHIVE_SFTP_PROFILE SOVIEZ_MIG_P22_S3_INTERRUPT \
    SOVIEZ_MIG_P22_SFTP_INTERRUPT SOVIEZ_MIG_P22_ARCHIVE_LOST_ACK \
    SOVIEZ_MIG_P22_LICENSE_RESPONSE_LOSS SOVIEZ_MIG_P22_RUNTIME_RESPONSE_LOSS 2>/dev/null || true
  soviez_fixture_midrun_network_gc || true
  echo "==> $t"
  local out
  out="$(mktemp -t soviez-run-all.XXXXXX)"
  if bash "$t" >"$out" 2>&1; then
    cat "$out"
    echo "OK $t"
  else
    cat "$out" >&2 || true
    echo "FAIL $t" >&2
    fail=1
  fi
  rm -f "$out"
  # Exact orphan volume reclaim (dangling/unreferenced only) — prevents Colima disk
  # exhaustion across long run_all sessions without broad volume prune.
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    docker volume ls -f dangling=true -q 2>/dev/null | while read -r v; do
      [[ -n "$v" ]] || continue
      docker volume rm "$v" >/dev/null 2>&1 || true
    done
  fi
  # After any suite that may bounce Colima, wait for Docker before continuing.
  if ! docker info >/dev/null 2>&1; then
    echo "[run_all] Docker down after $t — recovering Colima" >&2
    command -v colima >/dev/null 2>&1 && env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY colima start >/dev/null 2>&1 || true
    local i
    for i in $(seq 1 90); do
      docker info >/dev/null 2>&1 && break
      sleep 2
    done
    docker info >/dev/null 2>&1 || {
      echo "[run_all] FAIL: Docker unrecovered after $t" >&2
      fail=1
    }
  fi
  # Re-assert ERP fixture labels after any Docker recovery / image churn.
  if declare -F soviez_phase23_erp_fixture_ensure >/dev/null 2>&1; then
    soviez_phase23_erp_fixture_ensure || true
  fi
}

# Host-level Colima reboot suites mutate the Docker VM; run them last so earlier
# Docker-dependent suites are not left on a freshly restarted runtime.
deferred_tests=()
for t in tests/unit/test_*.sh tests/integration/test_*.sh tests/security/test_*.sh; do
  [[ -f "$t" ]] || continue
  case "$t" in
    *reboot_matrix*|*reboot_persistence*|*reboot_powerloss*|*autostart_prevention*|*/test_update_final_certification.sh)
      deferred_tests+=("$t")
      continue
      ;;
  esac
  run_one "$t"
done
for t in "${deferred_tests[@]}"; do
  run_one "$t"
done

# Security Gate S1 (docker) — run after unit/integration/security globs when docker available.
if [[ -x tests/security/run_security_gate_s1.sh ]]; then
  echo "==> tests/security/run_security_gate_s1.sh"
  if ! bash tests/security/run_security_gate_s1.sh; then
    echo "FAIL tests/security/run_security_gate_s1.sh" >&2
    fail=1
  fi
fi

if [[ -x tests/security/run_security_gate_s2.sh ]]; then
  echo "==> tests/security/run_security_gate_s2.sh"
  if ! SOVIEZ_S2_SKIP_NESTED_REGRESSIONS=1 bash tests/security/run_security_gate_s2.sh; then
    echo "FAIL tests/security/run_security_gate_s2.sh" >&2
    fail=1
  else
    echo "OK tests/security/run_security_gate_s2.sh"
  fi
fi
if [[ -x tests/security/run_security_gate_s3.sh ]]; then
  echo "==> tests/security/run_security_gate_s3.sh"
  if ! SOVIEZ_S3_SKIP_NESTED_REGRESSIONS=1 bash tests/security/run_security_gate_s3.sh; then
    echo "FAIL tests/security/run_security_gate_s3.sh" >&2
    fail=1
  else
    echo "OK tests/security/run_security_gate_s3.sh"
  fi
fi
if [[ -x tests/security/run_security_gate_s4.sh ]]; then
  echo "==> tests/security/run_security_gate_s4.sh"
  if ! SOVIEZ_S4_SKIP_NESTED_REGRESSIONS=1 bash tests/security/run_security_gate_s4.sh; then
    echo "FAIL tests/security/run_security_gate_s4.sh" >&2
    fail=1
  else
    echo "OK tests/security/run_security_gate_s4.sh"
  fi
fi
if [[ -x tests/security/run_security_gate_s5.sh ]]; then
  echo "==> tests/security/run_security_gate_s5.sh"
  if ! SOVIEZ_S5_SKIP_NESTED_REGRESSIONS=1 bash tests/security/run_security_gate_s5.sh; then
    echo "FAIL tests/security/run_security_gate_s5.sh" >&2
    fail=1
  else
    echo "OK tests/security/run_security_gate_s5.sh"
  fi
fi
if [[ -x tests/security/run_s5_corr_apt_lock.sh ]]; then
  echo "==> tests/security/run_s5_corr_apt_lock.sh"
  if ! SOVIEZ_CORR_SKIP_NESTED=1 bash tests/security/run_s5_corr_apt_lock.sh; then
    echo "FAIL tests/security/run_s5_corr_apt_lock.sh" >&2
    fail=1
  else
    echo "OK tests/security/run_s5_corr_apt_lock.sh"
  fi
fi
if [[ -x tests/security/run_security_gate_s6.sh ]]; then
  echo "==> tests/security/run_security_gate_s6.sh"
  if ! SOVIEZ_S6_SKIP_NESTED_REGRESSIONS=1 bash tests/security/run_security_gate_s6.sh; then
    echo "FAIL tests/security/run_security_gate_s6.sh" >&2
    fail=1
  else
    echo "OK tests/security/run_security_gate_s6.sh"
  fi
fi

if [[ -x tests/phase25_final_certification.sh ]]; then
  echo "==> tests/phase25_final_certification.sh (light)"
  if ! SOVIEZ_P25_SKIP_NESTED=1 SOVIEZ_P25_SKIP_RUN_ALL=1 bash tests/phase25_final_certification.sh; then
    echo "FAIL tests/phase25_final_certification.sh" >&2
    fail=1
  else
    echo "OK tests/phase25_final_certification.sh"
  fi
fi

if [[ $fail -ne 0 ]]; then
  echo "run_all: FAILED" >&2
  exit 1
fi
echo "run_all: PASS"
