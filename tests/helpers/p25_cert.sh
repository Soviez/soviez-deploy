#!/usr/bin/env bash
# shellcheck shell=bash
# Phase 25 — final certification helpers (orchestration only; no product changes).

P25_EXPECTED_VERSION="${P25_EXPECTED_VERSION:-0.24.5.3-registry-gateway}"
P25_EXPECTED_SHA256="${P25_EXPECTED_SHA256:-68ab59972d84d34f38c43862ca28946d3df3da5707fefa970230bd43e1da3460}"
P25_S6_CERT_SHA256="${P25_S6_CERT_SHA256:-68ab59972d84d34f38c43862ca28946d3df3da5707fefa970230bd43e1da3460}"

p25_cert_root() {
  local helper_root
  helper_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  printf '%s\n' "${SOVIEZ_SH_ROOT:-$helper_root}"
}

p25_run_id() {
  printf 'p25-%s-%s' "$(date -u +%Y%m%dT%H%M%SZ)" "${RANDOM}"
}

p25_evidence_root() {
  if [[ -n "${SOVIEZ_P25_EVIDENCE_ROOT:-}" ]]; then
    printf '%s\n' "$SOVIEZ_P25_EVIDENCE_ROOT"
    return 0
  fi
  local base="${SOVIEZ_TEST_MODE:-0}"
  if [[ "$base" == "1" ]]; then
    printf '%s\n' "${TMPDIR:-/tmp}/soviez-p25-evidence"
  else
    printf '%s\n' "${SOVIEZ_ROOT:-/var/lib/soviez}/certification/p25"
  fi
}

p25_evidence_init() {
  local run_id="${1:-$(p25_run_id)}"
  export SOVIEZ_P25_RUN_ID="$run_id"
  local root
  root="$(p25_evidence_root)/${run_id}"
  mkdir -p "$root"/{baseline,matrix,audit,hashes,artifacts}
  chmod 700 "$(p25_evidence_root)" 2>/dev/null || true
  chmod 700 "$root" 2>/dev/null || true
  cat >"$root/run_meta.json" <<EOF
{
  "run_id": "$run_id",
  "gate": "Phase25",
  "generated_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "certification_only": true,
  "artifact_version": "$P25_EXPECTED_VERSION",
  "artifact_sha256": "$P25_EXPECTED_SHA256",
  "telemetry": false,
  "local_only": true
}
EOF
  printf '%s\n' "$root"
}

p25_hash_file() {
  local f="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$f" | awk '{print $1}'
  else
    sha256sum "$f" | awk '{print $1}'
  fi
}

p25_write_json() {
  printf '%s\n' "$2" >"$1"
  chmod 600 "$1" 2>/dev/null || true
}

p25_assert_artifact_immutable() {
  local root ver sha
  root="$(p25_cert_root)"
  [[ -f "$root/dist/soviez.sh" ]] || { echo "FAIL dist/soviez.sh missing" >&2; return 1; }
  ver="$(tr -d '[:space:]' <"$root/VERSION")"
  sha="$(p25_hash_file "$root/dist/soviez.sh")"
  [[ "$ver" == "$P25_EXPECTED_VERSION" ]] || {
    echo "FAIL VERSION mismatch: got=$ver expected=$P25_EXPECTED_VERSION" >&2
    return 1
  }
  [[ "$sha" == "$P25_EXPECTED_SHA256" ]] || {
    echo "FAIL SHA256 mismatch: got=$sha expected=$P25_EXPECTED_SHA256" >&2
    return 1
  }
  echo "OK artifact immutable $ver ${sha:0:16}…"
  return 0
}

p25_platform_source() {
  # shellcheck disable=SC1091
  source "$(dirname "${BASH_SOURCE[0]}")/s1_platform.sh"
  s6_platform_source 2>/dev/null || s5_platform_source 2>/dev/null || s1_platform_source
}
