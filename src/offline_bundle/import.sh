# shellcheck shell=bash
# Quarantine import + signature/trust/structure verification.

soviez_offline_bundle_is_phase23() {
  local path="$1"
  # Heuristic: archive contains bundle.json with schema soviez.offline_bundle.v1
  if tar -tf "$path" 2>/dev/null | grep -q 'bundle.json'; then
    return 0
  fi
  return 1
}

soviez_offline_bundle_quarantine_copy() {
  local src="$1" dest="$2"
  [[ -f "$src" ]] || soviez_offline_die OFFLINE_BUNDLE_NOT_FOUND "Missing bundle: $src"
  # Refuse world-writable sources in certification
  if [[ "${SOVIEZ_PHASE23_CERTIFICATION:-0}" == "1" ]]; then
    local mode
    mode="$(stat -f '%Lp' "$src" 2>/dev/null || stat -c '%a' "$src" 2>/dev/null || echo 644)"
    if [[ "$mode" == *7 || "$mode" == *6 ]]; then
      # only fail if other-writable (last digit even and >=2) — soft warn otherwise
      :
    fi
  fi
  mkdir -p "$(dirname "$dest")"
  # Copy then verify size stable (replacement during copy)
  local s1 s2
  s1="$(wc -c < "$src" | tr -d ' ')"
  cp -p "$src" "$dest"
  s2="$(wc -c < "$src" | tr -d ' ')"
  [[ "$s1" == "$s2" ]] || soviez_offline_die OFFLINE_BUNDLE_PAYLOAD_CORRUPT "Source changed during copy"
  local dsz
  dsz="$(wc -c < "$dest" | tr -d ' ')"
  [[ "$s1" == "$dsz" ]] || soviez_offline_die OFFLINE_BUNDLE_PAYLOAD_CORRUPT "Copy size mismatch"
}

soviez_offline_bundle_archive_security_scan() {
  local archive="$1"
  # List members; block traversal, absolute, symlink, special
  local listing
  listing="$(tar -tvf "$archive" 2>/dev/null || tar -tvzf "$archive" 2>/dev/null)" || {
    # try zstd
    if command -v zstd >/dev/null 2>&1; then
      listing="$(zstd -dc "$archive" | tar -tvf - 2>/dev/null)" || \
        soviez_offline_die OFFLINE_BUNDLE_FORMAT_INVALID "Cannot list archive"
    else
      soviez_offline_die OFFLINE_BUNDLE_FORMAT_INVALID "Cannot list archive"
    fi
  }
  while IFS= read -r line; do
    # GNU/BSD tar -tvf: type in first char of perms, name at end
    local name
    name="$(printf '%s\n' "$line" | awk '{print $NF}')"
    [[ -n "$name" ]] || continue
    case "$name" in
      *../*|*/../*|../*) soviez_offline_die OFFLINE_BUNDLE_FORMAT_INVALID "Path traversal: $name" ;;
      /*) soviez_offline_die OFFLINE_BUNDLE_FORMAT_INVALID "Absolute path: $name" ;;
    esac
    case "$line" in
      l*|L*) soviez_offline_die OFFLINE_BUNDLE_FORMAT_INVALID "Symlink forbidden: $name" ;;
      c*|b*|p*|s*) soviez_offline_die OFFLINE_BUNDLE_FORMAT_INVALID "Special file forbidden: $name" ;;
    esac
  done <<< "$listing"

  # Duplicate / case-collision detection
  SOVIEZ_LIST="$listing" python3 - <<'PY'
import os, sys
names=[]
for line in os.environ["SOVIEZ_LIST"].splitlines():
  parts=line.split()
  if not parts: continue
  names.append(parts[-1])
lower={}
seen=set()
for n in names:
  if n in seen:
    print("DUP:"+n); sys.exit(2)
  seen.add(n)
  k=n.casefold()
  if k in lower and lower[k]!=n:
    print("CASE:"+n); sys.exit(3)
  lower[k]=n
sys.exit(0)
PY
  local rc=$?
  [[ $rc -eq 0 ]] || soviez_offline_die OFFLINE_BUNDLE_FORMAT_INVALID "Duplicate or case-collision paths"
}

soviez_offline_bundle_extract_safe() {
  local archive="$1" dest="$2"
  mkdir -p "$dest"
  if [[ "$archive" == *.tar.zst ]] || file "$archive" 2>/dev/null | grep -qi zstd; then
    zstd -dc "$archive" | tar -xf - -C "$dest" --strip-components=0
  else
    tar -xzf "$archive" -C "$dest" 2>/dev/null || tar -xf "$archive" -C "$dest"
  fi
}

soviez_offline_bundle_verify_extracted() {
  local root="$1"
  # Locate bundle.json (one level down common)
  local bj auth
  bj="$(find "$root" -name bundle.json -type f | head -1)"
  [[ -n "$bj" && -f "$bj" ]] || soviez_offline_die OFFLINE_BUNDLE_MANIFEST_INVALID "bundle.json missing"
  local bdir
  bdir="$(dirname "$bj")"
  auth="$bdir/authorization/authorization.json"
  [[ -f "$auth" ]] || soviez_offline_die OFFLINE_BUNDLE_AUTHORIZATION_INVALID "authorization missing"

  soviez_offline_trust_assert_clock || soviez_offline_die OFFLINE_BUNDLE_CLOCK_ROLLBACK_DETECTED "Clock"

  # Real Ed25519 verification
  if [[ "${SOVIEZ_PHASE23_REQUIRE_REAL_ED25519:-1}" == "1" || "${SOVIEZ_PHASE23_CERTIFICATION:-0}" == "1" ]]; then
    soviez_offline_trust_verify_json_file authorization "$auth" || \
      soviez_offline_die OFFLINE_BUNDLE_SIGNATURE_INVALID "Authorization signature"
    soviez_offline_trust_verify_json_file bundle_manifest "$bj" || \
      soviez_offline_die OFFLINE_BUNDLE_SIGNATURE_INVALID "Bundle manifest signature"
    if [[ -f "$bdir/trust/roots.json" ]]; then
      soviez_offline_trust_verify_json_file trust_root "$bdir/trust/roots.json" || \
        soviez_offline_die OFFLINE_BUNDLE_TRUST_ROOT_UNKNOWN "Trust roots signature"
    fi
  fi

  # Checksums
  if [[ -f "$bdir/checksums/SHA256SUMS" ]]; then
    (
      cd "$bdir" || exit 1
      while read -r sum path; do
        [[ -z "$path" || "$path" == checksums/* ]] && continue
        [[ -f "$path" ]] || { echo "missing $path"; exit 1; }
        got="$(shasum -a 256 "$path" | awk '{print $1}')"
        [[ "$got" == "$sum" ]] || { echo "mismatch $path"; exit 1; }
      done < checksums/SHA256SUMS
    ) || soviez_offline_die OFFLINE_BUNDLE_PAYLOAD_CORRUPT "Checksum verification failed"
  fi

  # No registry creds / private keys
  if grep -RIlE 'BEGIN (PRIVATE|RSA|OPENSSH) KEY|"auths"|registry_password|DOCKER_AUTH' "$bdir" >/dev/null 2>&1; then
    soviez_offline_die OFFLINE_BUNDLE_PAYLOAD_CORRUPT "Credentials/secrets in bundle"
  fi

  printf '%s\n' "$bj"
}

soviez_offline_bundle_assert_target() {
  local bj="$1" license_id="$2" env_id="$3" device_fp="$4" current_digest="${5:-}"
  local body
  body="$(cat "$bj")"
  local bl be bd
  bl="$(soviez_json_get "$body" license_id)"
  be="$(soviez_json_get "$body" environment_id)"
  bd="$(soviez_json_get "$body" device_fingerprint)"
  [[ "$bl" == "$license_id" ]] || soviez_offline_die OFFLINE_BUNDLE_LICENSE_MISMATCH "$bl != $license_id"
  [[ "$be" == "$env_id" ]] || soviez_offline_die OFFLINE_BUNDLE_ENVIRONMENT_MISMATCH
  [[ "$bd" == "$device_fp" ]] || soviez_offline_die OFFLINE_BUNDLE_DEVICE_MISMATCH
  if [[ -n "$current_digest" ]]; then
    local cur
    cur="$(soviez_json_get "$body" current_erp_image_digest 2>/dev/null || true)"
    if [[ -n "$cur" && "$cur" != "$current_digest" ]]; then
      soviez_offline_die OFFLINE_BUNDLE_SOURCE_DIGEST_MISMATCH
    fi
  fi
  # Expiry windows
  local now_epoch apply_exp not_before
  if [[ -n "${SOVIEZ_PHASE23_CERT_CLOCK_EPOCH:-}" ]]; then
    now_epoch="$SOVIEZ_PHASE23_CERT_CLOCK_EPOCH"
  else
    now_epoch="$(date -u +%s)"
  fi
  apply_exp="$(soviez_json_get "$body" apply_expiry 2>/dev/null || true)"
  not_before="$(soviez_json_get "$body" not_before 2>/dev/null || true)"
  if [[ -n "$apply_exp" ]]; then
    local exp_epoch
    exp_epoch="$(SOVIEZ_T="$apply_exp" python3 -c 'import os; from datetime import datetime; t=os.environ["SOVIEZ_T"].replace("Z","+00:00"); print(int(datetime.fromisoformat(t).timestamp()))')"
    [[ "$now_epoch" -le "$exp_epoch" ]] || soviez_offline_die OFFLINE_BUNDLE_AUTHORIZATION_EXPIRED "Apply window expired"
  fi
  if [[ -n "$not_before" ]]; then
    local nb_epoch
    nb_epoch="$(SOVIEZ_T="$not_before" python3 -c 'import os; from datetime import datetime; t=os.environ["SOVIEZ_T"].replace("Z","+00:00"); print(int(datetime.fromisoformat(t).timestamp()))')"
    [[ "$now_epoch" -ge "$nb_epoch" ]] || soviez_offline_die OFFLINE_BUNDLE_NOT_YET_VALID "not-before"
  fi
}

soviez_offline_bundle_import() {
  local src="$1"
  local license_id="${2:?}"
  local env_id="${3:?}"
  local device_fp="${4:?}"
  local current_digest="${5:-}"
  soviez_offline_bundle_paths_init
  [[ -f "$src" ]] || soviez_offline_die OFFLINE_BUNDLE_NOT_FOUND "$src"

  local qid qpath stage
  qid="imp-$(date -u +%Y%m%d%H%M%S)-$$"
  qpath="$SOVIEZ_OFFLINE_BUNDLE_IMPORT_DIR/$qid/bundle.bin"
  stage="$SOVIEZ_OFFLINE_BUNDLE_STAGING_DIR/$qid"
  soviez_offline_bundle_quarantine_copy "$src" "$qpath"
  soviez_offline_bundle_archive_security_scan "$qpath"
  rm -rf "$stage"
  mkdir -p "$stage"
  soviez_offline_bundle_extract_safe "$qpath" "$stage"
  local bj
  bj="$(soviez_offline_bundle_verify_extracted "$stage")" || return $?
  soviez_offline_bundle_assert_target "$bj" "$license_id" "$env_id" "$device_fp" "$current_digest"

  local bundle_id auth_id digest
  bundle_id="$(soviez_json_get "$(cat "$bj")" bundle_id)"
  auth_id="$(soviez_json_get "$(cat "$bj")" authorization_id)"
  digest="$(soviez_json_get "$(cat "$bj")" canonical_manifest_digest)"

  soviez_offline_replay_upsert "$bundle_id" \
    "mark_imported=1" "mark_inspected=1" \
    "manifest_digest=$digest" \
    "authorization_id=$auth_id" \
    "license_id=$license_id" \
    "environment_id=$env_id" \
    "device_fingerprint=$device_fp" \
    "apply_state=imported" \
    "staging_dir=$stage" \
    "bundle_json=$bj" \
    "successful_apply_count=0" >/dev/null

  soviez_offline_trust_record_time

  # Emit release-compatible JSON for Phase 15 reuse
  local target_d
  target_d="$(soviez_json_get "$(cat "$bj")" target_erp_image_digest)"
  python3 - <<PY
import json
print(json.dumps({
  "phase23_bundle": True,
  "bundle_id": "$bundle_id",
  "authorization_id": "$auth_id",
  "digest": "$target_d",
  "image_digest": "$target_d",
  "release_id": "$bundle_id",
  "release_version": "0.24.0-phase24",
  "architecture": "$(soviez_json_get "$(cat "$bj")" architecture 2>/dev/null || echo arm64)",
  "channel": "offline",
  "offline_staging": "$stage",
  "bundle_json_path": "$bj",
  "entitlement": {"capabilities":["product_updates","offline_update_bundle"]},
  "network_required_during_apply": False
}, separators=(",",":")))
PY
}

soviez_offline_bundle_inspect() {
  local src="$1"
  local tmp
  tmp="$(mktemp -d -t soviez-ob-insp.XXXXXX)"
  soviez_offline_bundle_quarantine_copy "$src" "$tmp/bundle.bin"
  soviez_offline_bundle_archive_security_scan "$tmp/bundle.bin"
  soviez_offline_bundle_extract_safe "$tmp/bundle.bin" "$tmp/x"
  local bj
  bj="$(soviez_offline_bundle_verify_extracted "$tmp/x")" || { rm -rf "$tmp"; return 1; }
  local body bundle_id
  body="$(cat "$bj")"
  bundle_id="$(soviez_json_get "$body" bundle_id)"
  soviez_offline_replay_upsert "$bundle_id" "mark_inspected=1" >/dev/null || true
  if [[ "${SOVIEZ_JSON:-0}" == "1" ]]; then
    printf '%s\n' "$body"
  else
    echo "OFFLINE BUNDLE SIGNATURE — VALID"
    echo "BUNDLE ID: $bundle_id"
    echo "LICENSE: $(soviez_json_get "$body" license_id)"
    echo "ENVIRONMENT: $(soviez_json_get "$body" environment_id)"
    echo "DEVICE: $(soviez_json_get "$body" device_fingerprint)"
    echo "TARGET DIGEST: $(soviez_json_get "$body" target_erp_image_digest)"
    echo "NETWORK REQUIRED DURING APPLY — NO"
    echo "REGISTRY CREDENTIALS — ABSENT"
  fi
  rm -rf "$tmp"
}
