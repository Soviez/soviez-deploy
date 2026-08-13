# shellcheck shell=bash

soviez_license_compute_fingerprint() {
  local op_id="$1"
  local tenant_id="${2:-unknown}"
  local material="${tenant_id}:${op_id}:$(hostname -f 2>/dev/null || hostname)"
  soviez_sha256_hex "$material"
}
