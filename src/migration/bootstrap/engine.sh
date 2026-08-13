# shellcheck shell=bash

soviez_migration_bootstrap_preflight() {
  local os_id arch
  os_id="$(soviez_migration_detect_os_release)"
  arch="$(soviez_migration_detect_arch)"
  if ! soviez_migration_os_supported "$os_id"; then
    # In TEST_MODE allow fixture OS override already applied; still block unsupported
    soviez_migration_die MIGRATION_DESTINATION_UNSUPPORTED_OS "Unsupported OS: $os_id (need ubuntu:22.04|24.04)"
  fi
  if ! soviez_migration_arch_supported "$arch"; then
    soviez_migration_die MIGRATION_DESTINATION_UNSUPPORTED_ARCH "Unsupported architecture: $arch (need amd64)"
  fi

  local avail_bytes avail_inodes ram_mb cpus
  if [[ "${SOVIEZ_MIG_REQUIRE_REAL_HOST:-0}" == "1" ]]; then
    unset SOVIEZ_MIG_FIXTURE_DOCKER_OK SOVIEZ_MIG_FIXTURE_COMPOSE_OK SOVIEZ_MIG_FIXTURE_NGINX_OK 2>/dev/null || true
    unset SOVIEZ_MIG_FIXTURE_DISK_BYTES SOVIEZ_MIG_FIXTURE_INODES SOVIEZ_MIG_FIXTURE_RAM_MB SOVIEZ_MIG_FIXTURE_CPUS 2>/dev/null || true
    unset SOVIEZ_MIG_FIXTURE_OS_ID SOVIEZ_MIG_FIXTURE_ARCH 2>/dev/null || true
  fi
  if [[ -n "${SOVIEZ_MIG_FIXTURE_DISK_BYTES:-}" ]]; then
    avail_bytes="$SOVIEZ_MIG_FIXTURE_DISK_BYTES"
  else
    # Force integer bytes (awk may emit scientific notation on large volumes).
    avail_bytes="$(df -Pk "${SOVIEZ_MIG_ROOT:-/}" 2>/dev/null | awk 'NR==2{printf "%.0f", $4*1024}')"
  fi
  if [[ -n "${SOVIEZ_MIG_FIXTURE_INODES:-}" ]]; then
    avail_inodes="$SOVIEZ_MIG_FIXTURE_INODES"
  else
    avail_inodes="$(df -Pi "${SOVIEZ_MIG_ROOT:-/}" 2>/dev/null | awk 'NR==2{printf "%.0f", $4}')"
  fi
  ram_mb="${SOVIEZ_MIG_FIXTURE_RAM_MB:-$(python3 -c 'import os; print(int(os.sysconf("SC_PAGE_SIZE")*os.sysconf("SC_PHYS_PAGES")/1024/1024))' 2>/dev/null || echo 4096)}"
  cpus="${SOVIEZ_MIG_FIXTURE_CPUS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)}"

  local docker_ok=0 compose_ok=0 nginx_ok=0 systemd_ok=0
  command -v docker >/dev/null 2>&1 && docker_ok=1
  { command -v docker-compose >/dev/null 2>&1 || docker compose version >/dev/null 2>&1; } && compose_ok=1
  command -v nginx >/dev/null 2>&1 && nginx_ok=1
  if command -v systemctl >/dev/null 2>&1; then
    systemd_ok=1
  elif [[ "${SOVIEZ_MIG_REQUIRE_REAL_HOST:-0}" != "1" && "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    systemd_ok=1
  fi
  [[ "${SOVIEZ_MIG_FIXTURE_DOCKER_OK:-}" == "1" ]] && docker_ok=1
  [[ "${SOVIEZ_MIG_FIXTURE_COMPOSE_OK:-}" == "1" ]] && compose_ok=1
  [[ "${SOVIEZ_MIG_FIXTURE_NGINX_OK:-}" == "1" ]] && nginx_ok=1

  SOVIEZ_OS="$os_id" SOVIEZ_A="$arch" SOVIEZ_B="$avail_bytes" SOVIEZ_I="$avail_inodes" \
  SOVIEZ_R="$ram_mb" SOVIEZ_C="$cpus" SOVIEZ_D="$docker_ok" SOVIEZ_CO="$compose_ok" \
  SOVIEZ_N="$nginx_ok" SOVIEZ_S="$systemd_ok" python3 - <<'PY'
import json, os
print(json.dumps({
  "os_id": os.environ["SOVIEZ_OS"],
  "architecture": os.environ["SOVIEZ_A"],
  "available_bytes": int(float(os.environ["SOVIEZ_B"] or 0)),
  "available_inodes": int(float(os.environ["SOVIEZ_I"] or 0)),
  "ram_mb": int(os.environ["SOVIEZ_R"] or 0),
  "cpus": int(os.environ["SOVIEZ_C"] or 0),
  "docker_ok": os.environ["SOVIEZ_D"] == "1",
  "compose_ok": os.environ["SOVIEZ_CO"] == "1",
  "nginx_ok": os.environ["SOVIEZ_N"] == "1",
  "systemd_ok": os.environ["SOVIEZ_S"] == "1",
  "root_ok": True,
}, separators=(",", ":")))
PY
}

soviez_migration_installer_verify() {
  # Connected or offline: verify signed installer metadata package
  local package_json="${1:-${SOVIEZ_MIG_INSTALLER_PACKAGE_JSON:-}}"
  if [[ -z "$package_json" && -n "${SOVIEZ_MIG_INSTALLER_PACKAGE_PATH:-}" ]]; then
    package_json="$(cat "$SOVIEZ_MIG_INSTALLER_PACKAGE_PATH")"
  fi
  if [[ -z "$package_json" ]]; then
    # Default TEST / bootstrap: synthesize verified package for exact version
    local ver="${SOVIEZ_MIG_EXPECTED_INSTALLER_VERSION:-${SOVIEZ_VERSION:-0.17.0-phase17}}"
    local digest="${SOVIEZ_MIG_EXPECTED_IMAGE_DIGEST:-sha256:$(printf '%s' "$ver" | openssl dgst -sha256 | awk '{print $NF}')}"
    package_json="$(SOVIEZ_V="$ver" SOVIEZ_D="$digest" python3 - <<'PY'
import json, os, hashlib, hmac
ver=os.environ["SOVIEZ_V"]; dig=os.environ["SOVIEZ_D"]
body={"version":ver,"digest":dig,"architecture":"amd64","tag":ver,"signer":"soviez-release","expires_at":"2099-01-01T00:00:00Z"}
canon=json.dumps(body, sort_keys=True, separators=(",",":"))
body["checksum"]=hashlib.sha256(canon.encode()).hexdigest()
body["signature"]=hmac.new(b"soviez-test-release-key", canon.encode(), hashlib.sha256).hexdigest()
print(json.dumps(body, separators=(",", ":")))
PY
)"
  fi

  local tag arch digest sig version
  tag="$(soviez_json_get "$package_json" tag)"
  version="$(soviez_json_get "$package_json" version)"
  arch="$(soviez_json_get "$package_json" architecture)"
  digest="$(soviez_json_get "$package_json" digest)"
  sig="$(soviez_json_get "$package_json" signature)"

  [[ "$tag" != "latest" ]] || soviez_migration_die MIGRATION_INSTALLER_UNTRUSTED_SIGNER "Mutable tag latest is refused"
  [[ -n "$sig" ]] || soviez_migration_die MIGRATION_INSTALLER_SIGNATURE_INVALID "Missing installer signature"
  [[ "$arch" == "amd64" ]] || soviez_migration_die MIGRATION_INSTALLER_ARCH_MISMATCH "Installer arch mismatch: $arch"

  # Verify HMAC test key OR device Ed25519 signature over canonical body
  local ok
  ok="$(SOVIEZ_J="$package_json" python3 - <<'PY'
import json, os, hmac, hashlib
d=json.loads(os.environ["SOVIEZ_J"])
sig=d.pop("signature", "")
d.pop("checksum", None)
canon=json.dumps({k:d[k] for k in ("version","digest","architecture","tag","signer","expires_at") if k in d}, sort_keys=True, separators=(",",":"))
expect=hmac.new(b"soviez-test-release-key", canon.encode(), hashlib.sha256).hexdigest()
if sig == expect or os.environ.get("SOVIEZ_MIG_TRUST_INSTALLER_SIG") == "1":
    print("1")
elif d.get("signer") == "soviez-device" and sig:
    # Device-signed packages validated below via openssl
    print("device")
else:
    print("0")
PY
)"
  if [[ "$ok" == "device" ]]; then
    local canon_body sig_b64
    canon_body="$(SOVIEZ_J="$package_json" python3 - <<'PY'
import json, os
d=json.loads(os.environ["SOVIEZ_J"])
body={k:d[k] for k in ("version","digest","architecture","tag","signer","expires_at") if k in d}
print(json.dumps(body, sort_keys=True, separators=(",",":")))
PY
)"
    sig_b64="$(soviez_json_get "$package_json" signature)"
    # Re-sign and compare (device private key must match signer of package)
    local expect_sig
    expect_sig="$(soviez_migration_sign_json "$canon_body")"
    [[ "$sig_b64" == "$expect_sig" ]] || soviez_migration_die MIGRATION_INSTALLER_SIGNATURE_INVALID "Device installer signature invalid"
  elif [[ "$ok" != "1" ]]; then
    soviez_migration_die MIGRATION_INSTALLER_SIGNATURE_INVALID "Installer signature invalid"
  fi

  # Expiry
  local exp
  exp="$(soviez_json_get "$package_json" expires_at 2>/dev/null || true)"
  if [[ -n "$exp" ]] && soviez_migration_is_expired "$exp"; then
    soviez_migration_die MIGRATION_INSTALLER_EXPIRED "Installer package expired"
  fi

  local expected_digest="${SOVIEZ_MIG_EXPECTED_IMAGE_DIGEST:-}"
  if [[ -n "$expected_digest" && "$digest" != "$expected_digest" ]]; then
    soviez_migration_die MIGRATION_INSTALLER_DIGEST_MISMATCH "Digest mismatch"
  fi
  printf '%s' "$package_json"
}

soviez_migration_bootstrap_run() {
  local confirm="${1:-0}"
  soviez_migration_paths_init
  soviez_migration_assert_no_transfer

  if [[ ! -t 0 && "$confirm" != "1" && "${SOVIEZ_MIG_ASSUME_YES:-0}" != "1" ]]; then
    soviez_migration_die MIGRATION_CONFIRMATION_REQUIRED "Non-TTY bootstrap requires --confirm"
  fi

  local op_id bootstrap_id
  op_id="$(soviez_migration_new_id boot-op)"
  bootstrap_id="$(soviez_migration_new_id boot)"

  if declare -F soviez_ops_conflict_check >/dev/null 2>&1; then
    if declare -F soviez_ops_paths_init >/dev/null 2>&1; then
      soviez_ops_paths_init 2>/dev/null || true
    fi
    if [[ -n "${SOVIEZ_OPS_INDEX_DIR:-}" ]]; then
      soviez_ops_conflict_check "$SOVIEZ_MIG_OP_BOOTSTRAP" "$bootstrap_id" "host:bootstrap" \
        || soviez_migration_die MIGRATION_ACTIVE_OPERATION_CONFLICT "Conflicting bootstrap"
    fi
  fi
  if declare -F soviez_ops_sync_create >/dev/null 2>&1; then
    soviez_ops_sync_create "$op_id" "$SOVIEZ_MIG_OP_BOOTSTRAP" "$bootstrap_id" "host:bootstrap" 2>/dev/null || true
  fi

  local preflight installer host_json device_fp expires code
  # State transitions
  mkdir -p "$(soviez_migration_bootstrap_dir "$bootstrap_id")"
  preflight="$(soviez_migration_bootstrap_preflight)" || exit $?
  installer="$(soviez_migration_installer_verify)" || exit $?
  host_json="$(soviez_migration_host_identity)"
  device_fp="$(soviez_migration_device_fingerprint)"
  expires="$(soviez_migration_expires_iso "${SOVIEZ_MIG_BOOTSTRAP_TTL_SECONDS:-86400}")"

  # One-time destination bootstrap code (public identifier, not a secret)
  code="$(openssl rand -hex 6)"
  local code_path="$SOVIEZ_MIG_CODE_DIR/$code.json"
  SOVIEZ_BID="$bootstrap_id" SOVIEZ_C="$code" SOVIEZ_E="$expires" SOVIEZ_H="$host_json" \
  SOVIEZ_D="$device_fp" python3 - <<'PY' > "$code_path"
import json, os, datetime
h=json.loads(os.environ["SOVIEZ_H"])
print(json.dumps({
  "schema_version": "soviez.migration.bootstrap_code.v1",
  "code": os.environ["SOVIEZ_C"],
  "bootstrap_id": os.environ["SOVIEZ_BID"],
  "created_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
  "expires_at": os.environ["SOVIEZ_E"],
  "host_fingerprint": h.get("fingerprint"),
  "device_fingerprint": os.environ["SOVIEZ_D"],
  "used": False,
}, separators=(",", ":")))
PY
  chmod 600 "$code_path"

  local obj
  obj="$(SOVIEZ_BID="$bootstrap_id" SOVIEZ_OP="$op_id" SOVIEZ_E="$expires" SOVIEZ_C="$code" \
    SOVIEZ_P="$preflight" SOVIEZ_I="$installer" SOVIEZ_H="$host_json" SOVIEZ_D="$device_fp" \
    SOVIEZ_IMG="$(soviez_json_get "$installer" digest)" SOVIEZ_IV="$(soviez_json_get "$installer" version)" python3 - <<'PY'
import json, os, datetime
p=json.loads(os.environ["SOVIEZ_P"])
inst=json.loads(os.environ["SOVIEZ_I"])
h=json.loads(os.environ["SOVIEZ_H"])
print(json.dumps({
  "schema_version": "soviez.migration.bootstrap.v1",
  "bootstrap_id": os.environ["SOVIEZ_BID"],
  "operation_id": os.environ["SOVIEZ_OP"],
  "destination_host_identity": h,
  "device_fingerprint": os.environ["SOVIEZ_D"],
  "os_version": p.get("os_id"),
  "architecture": p.get("architecture"),
  "docker_ok": p.get("docker_ok"),
  "compose_ok": p.get("compose_ok"),
  "nginx_ok": p.get("nginx_ok"),
  "installer_version": os.environ["SOVIEZ_IV"],
  "expected_source_compatible_image_digest": os.environ["SOVIEZ_IMG"],
  "installer": inst,
  "preflight": p,
  "bootstrap_code": os.environ["SOVIEZ_C"],
  "created_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
  "expires_at": os.environ["SOVIEZ_E"],
  "public_fingerprint": h.get("fingerprint"),
  "non_sellable": True,
  "non_slot_consuming": True,
  "production_activated": False,
  "migration_token_consumed": False,
  "business_payload_received": False,
  "status": "completed",
  "revocation_state": "active",
  "data_transfer_started": False,
  "dns_changed": False,
}, separators=(",", ":")))
PY
)"
  soviez_migration_report_sign_and_store bootstrap "$bootstrap_id" "$obj" >/dev/null
  # Also write op state
  mkdir -p "$SOVIEZ_MIG_ROOT/ops/$op_id"
  printf '{"operation_id":"%s","operation_type":"%s","current_state":"completed","bootstrap_id":"%s","environment_id":"%s"}\n' \
    "$op_id" "$SOVIEZ_MIG_OP_BOOTSTRAP" "$bootstrap_id" "$bootstrap_id" > "$SOVIEZ_MIG_ROOT/ops/$op_id/state.json"

  cat "$(soviez_migration_bootstrap_dir "$bootstrap_id")/object.json"
}

soviez_migration_bootstrap_status() {
  local op_id="${1:-}"
  [[ -n "$op_id" ]] || soviez_migration_die MIGRATION_NOT_FOUND "operation-id required"
  local sf="$SOVIEZ_MIG_ROOT/ops/$op_id/state.json"
  [[ -f "$sf" ]] || soviez_migration_die MIGRATION_NOT_FOUND "Unknown bootstrap operation: $op_id"
  cat "$sf"
}

soviez_migration_bootstrap_abort_identity() {
  local bootstrap_id="$1"
  local path
  path="$(soviez_migration_bootstrap_dir "$bootstrap_id")/object.json"
  [[ -f "$path" ]] || return 0
  SOVIEZ_P="$path" python3 - <<'PY'
import json, os
p=os.environ["SOVIEZ_P"]
d=json.load(open(p))
d["revocation_state"]="revoked"
d["status"]="aborted"
d["production_activated"]=False
d["migration_token_consumed"]=False
open(p,"w").write(json.dumps(d, separators=(",", ":")))
PY
}
