#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/p25_cert.sh"
EVID="${SOVIEZ_P25_EVIDENCE_DIR:?SOVIEZ_P25_EVIDENCE_DIR required}"
mkdir -p "$EVID/baseline"
sha="$(p25_hash_file "$ROOT/dist/soviez.sh")"
ver="$(tr -d '[:space:]' <"$ROOT/VERSION")"
git_head="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo NO_COMMIT)"
dirty_count="$(git -C "$ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
{
  echo "# BASELINE"
  echo
  echo "run_id=${SOVIEZ_P25_RUN_ID:-unknown}"
  echo "repository=$ROOT"
  echo "git_head=$git_head"
  echo "dirty_entries=$dirty_count"
  echo "zero_commit=$([[ "$git_head" == NO_COMMIT ]] && echo yes || echo no)"
  echo "installer_version=$ver"
  echo "artifact_sha256=$sha"
  echo "expected_version=$P25_EXPECTED_VERSION"
  echo "expected_sha256=$P25_EXPECTED_SHA256"
  echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "host=$(uname -a)"
  echo "docker_host=${DOCKER_HOST:-unset}"
  echo "s6_certificate=docs/evidence/security-gate-s6/SECURITY_CERTIFICATE.md"
} >"$EVID/baseline/BASELINE_SNAPSHOT.md"
echo "OK baseline"
exit 0
