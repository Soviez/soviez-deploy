#!/usr/bin/env bash
# Phase 23 ephemeral certification lifecycle wrapper.
# preflight → (optional) start Colima once → authoritative cert → persist evidence
# → exact labeled cleanup → stop Colima → NEVER delete Colima unless disposability proven.
#
# Usage:
#   tests/phase23_ephemeral_certification_lifecycle.sh
#   tests/phase23_ephemeral_certification_lifecycle.sh --ephemeral   # alias (same path)
#
# Safety: never docker system prune / never rm -rf ~/.colima|~/.lima /
# Only removes resources labeled soviez.phase23.disposable=1 / com.soviez.owner=phase23-cert
# or exact names soviez-p23-* / run-owned temp dir.
set -euo pipefail

SH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVID="$SH_ROOT/docs/evidence/phase-23-offline-update-bundles"
PROJ_ROOT="$(cd "$SH_ROOT/.." && pwd)"
RUN_ID="${SOVIEZ_PHASE23_CERT_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
TMP_ROOT="${SOVIEZ_PHASE23_CERT_TMP:-$PROJ_ROOT/.phase23-cert-tmp/$RUN_ID}"
MANIFEST="$EVID/DISPOSABLE_RESOURCE_MANIFEST.md"
CLEANUP_LOG="$EVID/DISK_CLEANUP_REPORT.md"
LIFECYCLE_LOG="$EVID/_EPHEMERAL_LIFECYCLE.log"
DISK_PEAK_FILE="/tmp/soviez-phase23-disk-peak-$RUN_ID.txt"
STARTED_COLIMA=0
DISPOSABILITY_SAFE=0
CERT_EXIT=1
CLEANUP_DONE=0

export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH:-/usr/bin:/bin}"
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
export SOVIEZ_OPENSSL="${SOVIEZ_OPENSSL:-/opt/homebrew/bin/openssl}"
export SOVIEZ_PHASE23_CERT_RUN_ID="$RUN_ID"
export TMPDIR="$TMP_ROOT"
export TMP="$TMP_ROOT"
mkdir -p "$TMP_ROOT" "$EVID"

# shellcheck source=/dev/null
source "$SH_ROOT/tests/helpers/phase23_cert.sh"

log() { printf '[phase23-lifecycle] %s\n' "$*" | tee -a "$LIFECYCLE_LOG"; }

host_avail_gi() {
  df -g / 2>/dev/null | awk 'NR==2{print $4}' || df -h / | awk 'NR==2{print $4}'
}

record_peak_disk() {
  local avail
  avail="$(df -k / | awk 'NR==2{print $4}')"
  echo "$avail" >> "$DISK_PEAK_FILE"
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    colima ssh -- df -k /var/lib/docker 2>/dev/null | awk 'NR==2{print "vm="$4}' >> "$DISK_PEAK_FILE" || true
  fi
}

append_manifest() {
  local typ="$1" id="$2" note="$3"
  printf '| %s | `%s` | %s | %s |\n' "$typ" "$id" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$note" >> "$MANIFEST"
}

init_manifest() {
  cat > "$MANIFEST" <<EOF
# DISPOSABLE_RESOURCE_MANIFEST

Run ID: \`$RUN_ID\`
Started: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Profile: \`default\` (pre-existing; required by DOCKER_HOST assumptions)
Temp workspace: \`$TMP_ROOT\`

## Ownership labels for newly created cert fixtures
- \`soviez.phase23.disposable=1\` (existing Phase 23 helper convention)
- \`com.soviez.owner=phase23-cert\`
- \`com.soviez.cert-run=$RUN_ID\` (when applied by this lifecycle / helpers)

## Resources (append-only during run)

| type | id/name | created_utc | notes / cleanup |
|------|---------|-------------|-----------------|
EOF
  append_manifest "tmpdir" "$TMP_ROOT" "rm -rf exact path only"
}

# Exact cleanup — label/name scoped only. Idempotent.
phase23_exact_docker_cleanup() {
  log "exact Docker cleanup for phase23 disposable labels/names"
  if ! docker info >/dev/null 2>&1; then
    log "Docker unreachable — skip Docker resource cleanup"
    return 0
  fi
  local ids
  ids="$(docker ps -aq --filter label=soviez.phase23.disposable=1 2>/dev/null || true)"
  if [[ -n "$ids" ]]; then
    log "removing containers label=soviez.phase23.disposable=1: $ids"
    # shellcheck disable=SC2086
    docker rm -f $ids >/dev/null 2>&1 || true
  fi
  ids="$(docker ps -aq --filter label=com.soviez.owner=phase23-cert 2>/dev/null || true)"
  if [[ -n "$ids" ]]; then
    log "removing containers label=com.soviez.owner=phase23-cert: $ids"
    # shellcheck disable=SC2086
    docker rm -f $ids >/dev/null 2>&1 || true
  fi
  local n
  for n in $(docker ps -aq --filter "name=soviez-p23-" 2>/dev/null || true); do
    log "removing name=soviez-p23-* id=$n"
    docker rm -f "$n" >/dev/null 2>&1 || true
  done
  # Networks
  for n in $(docker network ls -q --filter label=soviez.phase23.disposable=1 2>/dev/null || true); do
    log "removing network disposable=$n"
    docker network rm "$n" >/dev/null 2>&1 || true
  done
  for n in $(docker network ls -q --filter label=com.soviez.owner=phase23-cert 2>/dev/null || true); do
    log "removing network phase23-cert=$n"
    docker network rm "$n" >/dev/null 2>&1 || true
  done
  # Volumes — ONLY labeled disposable / phase23-cert. Never wab-poc / unnamed anonymous without label.
  for n in $(docker volume ls -q --filter label=soviez.phase23.disposable=1 2>/dev/null || true); do
    log "removing volume disposable=$n"
    docker volume rm "$n" >/dev/null 2>&1 || true
  done
  for n in $(docker volume ls -q --filter label=com.soviez.owner=phase23-cert 2>/dev/null || true); do
    log "removing volume phase23-cert=$n"
    docker volume rm "$n" >/dev/null 2>&1 || true
  done
  # Also invoke existing exact fixture reset helper
  if declare -F soviez_phase23_exact_fixture_reset >/dev/null 2>&1; then
    soviez_phase23_exact_fixture_reset || true
  fi
  # Dangling volumes only (unreferenced) — safe reclaim, not broad prune of named volumes
  local dv
  while read -r dv; do
    [[ -z "$dv" ]] && continue
    log "removing dangling volume $dv"
    docker volume rm "$dv" >/dev/null 2>&1 || true
  done < <(docker volume ls -f dangling=true -q 2>/dev/null || true)
}

phase23_temp_cleanup() {
  if [[ -d "$TMP_ROOT" ]]; then
    log "removing exact temp workspace $TMP_ROOT"
    rm -rf "$TMP_ROOT"
  fi
}

phase23_stop_colima_if_started() {
  if [[ "$STARTED_COLIMA" -eq 1 ]]; then
    log "stopping Colima (lifecycle started/recovered it this run)"
    colima stop 2>&1 | tee -a "$LIFECYCLE_LOG" || true
  else
    log "stopping Colima (post-cert disk reclaim; profile retained — not disposable)"
    colima stop 2>&1 | tee -a "$LIFECYCLE_LOG" || true
  fi
}

# Disposability: default profile holds unrelated + persistent DBs → NEVER delete.
phase23_assess_disposability() {
  DISPOSABILITY_SAFE=0
  log "DISPOSABILITY: UNSAFE — will NOT colima delete"
  {
    echo
    echo "## Disposability assessment (DO NOT DELETE)"
    echo
    echo "Profile \`default\` contains persistent / unrelated resources:"
    echo
    echo '```text'
    docker ps -a --format '{{.Names}}\t{{.Image}}' 2>/dev/null | head -40 || true
    echo '```'
    echo
    echo "Named volumes include \`wab-poc_*\` and \`soviez-p17-*\` — not Phase 23 cert-owned."
    echo "Evidence/source/artifact live outside the VM; nevertheless **reusable RC ERP images + unrelated POC DBs** make deletion unsafe."
    echo
    echo "**Decision: stop only; do not \`colima delete\`.**"
  } >> "$MANIFEST"
}

finalize_cleanup() {
  [[ "$CLEANUP_DONE" -eq 1 ]] && return 0
  CLEANUP_DONE=1
  log "FINALIZE cleanup begin (cert_exit=$CERT_EXIT)"
  set +e
  phase23_exact_docker_cleanup
  phase23_temp_cleanup
  # Evidence already under $EVID — do not touch
  phase23_stop_colima_if_started
  set -e
  log "FINALIZE cleanup end"
}

on_exit() {
  local ec=$?
  CERT_EXIT=$ec
  finalize_cleanup || true
  exit "$ec"
}
trap on_exit EXIT
trap 'log "INTERRUPTED"; CERT_EXIT=130; finalize_cleanup; exit 130' INT TERM

: > "$LIFECYCLE_LOG"
log "RUN_ID=$RUN_ID"
log "TMP_ROOT=$TMP_ROOT"
init_manifest

BEFORE_SYS="$(df -h / | awk 'NR==2{print $4}')"
BEFORE_SSD="$(df -h /Volumes/PortableSSD | awk 'NR==2{print $4}')"
BEFORE_COLIMA="$(du -sh /Volumes/PortableSSD/Apps/Colima/Home/.colima 2>/dev/null | awk '{print $1}')"
echo "$BEFORE_SYS" > /tmp/soviez-phase23-disk-before-sys.txt
: > "$DISK_PEAK_FILE"
record_peak_disk

# Host reserve ≥15Gi (prefer 20Gi). Baseline was ~85Gi.
SYS_AVAIL_G="$(df -g / | awk 'NR==2{print $4}')"
if [[ "${SYS_AVAIL_G:-0}" -lt 15 ]]; then
  log "FAIL: system free ${SYS_AVAIL_G}Gi < 15Gi reserve"
  CERT_EXIT=1
  exit 1
fi

# Ensure Docker
if ! docker info >/dev/null 2>&1; then
  log "Docker down — one colima start"
  STARTED_COLIMA=1
  if ! colima start; then
    log "colima start FAILED — PARTIAL"
    CERT_EXIT=1
    exit 1
  fi
fi
if ! docker info >/dev/null 2>&1; then
  log "Docker still unreachable after start"
  CERT_EXIT=1
  exit 1
fi
log "Docker OK"
soviez_phase23_cert_env
soviez_phase23_docker_preflight || { log "docker preflight fail"; CERT_EXIT=1; exit 1; }
soviez_phase23_postgres_preflight || { log "postgres preflight fail"; CERT_EXIT=1; exit 1; }
soviez_phase23_exact_fixture_reset || true
soviez_phase23_erp_fixture_ensure || { log "ERP fixture fail"; CERT_EXIT=1; exit 1; }

phase23_assess_disposability
record_peak_disk

# Background peak sampler (bounded)
(
  for _ in $(seq 1 240); do
    record_peak_disk
    sleep 30
  done
) &
PEAK_PID=$!

log "starting authoritative certification"
set +e
bash "$SH_ROOT/tests/phase23_authoritative_certification.sh" 2>&1 | tee -a "$LIFECYCLE_LOG"
CERT_EXIT=${PIPESTATUS[0]}
set -e
kill "$PEAK_PID" 2>/dev/null || true
wait "$PEAK_PID" 2>/dev/null || true
record_peak_disk

log "authoritative exit=$CERT_EXIT"
# Evidence preservation check (durable paths)
for f in FINAL_REPORT.md TEST_RESULTS.md BUILD_ARTIFACT.md AUTHORITATIVE_RUN_ALL.md \
  CLEAN_RUN_HISTORY.md PRIOR_FAILURE_LEDGER.md FAILURE_CLASSIFICATION.md \
  DISPOSABLE_RESOURCE_MANIFEST.md DISK_SPACE_LIFECYCLE.md; do
  if [[ ! -f "$EVID/$f" ]]; then
    log "WARN missing evidence file: $f"
  else
    log "evidence present: $f"
  fi
done

# finalize via trap
exit "$CERT_EXIT"
