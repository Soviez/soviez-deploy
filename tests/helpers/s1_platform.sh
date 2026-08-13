#!/usr/bin/env bash
# shellcheck shell=bash
# Source S1+S2 platform modules for security tests (assembled dist preferred).
s1_platform_source() {
  local root helper_root
  helper_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  root="${SOVIEZ_SH_ROOT:-}"
  # Prefer explicit root only when it looks like soviez-sh
  if [[ -z "$root" || ! -f "$root/VERSION" || ! -d "$root/src/security" ]]; then
    root="$helper_root"
  fi
  export SOVIEZ_SH_ROOT="$root"
  export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"

  if [[ -f "$root/dist/soviez.sh" ]]; then
    # shellcheck disable=SC1090
    source "$root/dist/soviez.sh"
    export SOVIEZ_S3_SHARE_DIR="${SOVIEZ_S3_SHARE_DIR:-$root/share/security/detection}"
    return 0
  fi
  if declare -F soviez_sec_source_platform_modules >/dev/null 2>&1; then
    soviez_sec_source_platform_modules
    return 0
  fi
  local f
  for f in \
    report.sh secrets_baseline.sh credential_policy.sh postgres_roles.sh \
    postgres_network.sh odoo_exposure.sh docker_containment.sh odoo_defaults.sh \
    websocket_topology.sh rollback.sh remediate_existing.sh critical_gate.sh \
    firewall.sh firewall_ufw.sh firewall_firewalld.sh firewall_nftables.sh \
    docker_firewall.sh nginx_edge.sh cloudflare.sh edge.sh ssh.sh \
    brute_force.sh management_surface.sh host_baseline.sh persistence_audit.sh \
    s2_rollback.sh s2_gate.sh legacy_bridge.sh
  do
    # shellcheck disable=SC1090
    source "$root/src/security/platform/$f"
  done
  for f in \
    evidence.sh db_context.sh db_scan.sh db_baseline.sh addon_scan.sh yara_scan.sh \
    host_integrity.sh process_scan.sh network_ioc.sh persistence_scan.sh \
    retention.sh tooling_policy.sh s3_report.sh s3_gate.sh
  do
    # shellcheck disable=SC1090
    source "$root/src/security/detection/$f"
  done
  for f in \
    state.sh classify_source.sh secrets.sh archive_validate.sh network.sh cron.sh \
    mail.sh integrations.sh preboot_scan.sh filestore.sh restore.sh migration.sh \
    promotion.sh rollback.sh report.sh cleanup.sh gate.sh
  do
    # shellcheck disable=SC1090
    source "$root/src/security/quarantine/$f"
  done
  for f in \
    baseline.sh network.sh dns.sh outbound.sh pdf.sh restart.sh reboot.sh \
    apt_lock.sh package_policy.sh rollback.sh report.sh gate.sh
  do
    # shellcheck disable=SC1090
    source "$root/src/security/update_safety/$f"
  done
  for f in \
    posture.sh integrity.sh encryption.sh secret_scan.sh retention.sh \
    restore_verify.sh disk.sh report.sh gate.sh
  do
    # shellcheck disable=SC1090
    source "$root/src/security/backup_safety/$f"
  done
  export SOVIEZ_S3_SHARE_DIR="${SOVIEZ_S3_SHARE_DIR:-$root/share/security/detection}"
}

s2_platform_source() { s1_platform_source; }
s3_platform_source() { s1_platform_source; }
s4_platform_source() { s1_platform_source; }
s5_platform_source() { s1_platform_source; }
s6_platform_source() { s1_platform_source; }

s1_run_id() {
  printf 's1-%s-%s' "$(date +%s)" "${RANDOM}"
}

s2_run_id() {
  printf 's2-%s-%s' "$(date +%s)" "${RANDOM}"
}

s3_run_id() {
  printf 's3-%s-%s' "$(date +%s)" "${RANDOM}"
}

s4_run_id() {
  printf 's4-%s-%s' "$(date +%s)" "${RANDOM}"
}

s5_run_id() {
  printf 's5-%s-%s' "$(date +%s)" "${RANDOM}"
}

s6_run_id() {
  printf 's6-%s-%s' "$(date +%s)" "${RANDOM}"
}

s1_cleanup_containers() {
  local prefix="${1:-soviez-s1-}"
  local names
  names="$(docker ps -aq --filter "name=${prefix}" 2>/dev/null || true)"
  if [[ -n "$names" ]]; then
    # shellcheck disable=SC2086
    docker rm -f $names >/dev/null 2>&1 || true
  fi
  local nets
  nets="$(docker network ls --format '{{.Name}}' 2>/dev/null | grep "^${prefix}" || true)"
  local n
  for n in $nets; do
    docker network rm "$n" >/dev/null 2>&1 || true
  done
}

s2_cleanup_containers() {
  s1_cleanup_containers "${1:-soviez-s2-}"
}

s5_cleanup_containers() {
  s1_cleanup_containers "${1:-soviez-s5-}"
}

s6_cleanup_containers() {
  s1_cleanup_containers "${1:-soviez-s6-}"
}
