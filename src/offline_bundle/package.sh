# shellcheck shell=bash
# Deterministic full-bundle packaging (tar.zst preferred; tar.gz fallback).

soviez_offline_bundle_sha256_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

soviez_offline_bundle_write_manifest() {
  local out="$1"
  shift
  # Remaining args as KEY=VALUE pairs fed to python
  SOVIEZ_OUT="$out" python3 - "$@" <<'PY'
import json, os, sys, hashlib, datetime
kv={}
for a in sys.argv[1:]:
  if "=" in a:
    k,v=a.split("=",1)
    kv[k]=v
now=kv.get("issued_at") or datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
doc={
  "schema_version":"soviez.offline_bundle.v1",
  "bundle_format_version":"1",
  "bundle_type":kv.get("bundle_type","full"),
  "bundle_id":kv["bundle_id"],
  "authorization_id":kv.get("authorization_id",""),
  "issuance_id":kv.get("issuance_id",""),
  "account_id":kv.get("account_id",""),
  "license_id":kv["license_id"],
  "environment_id":kv["environment_id"],
  "device_fingerprint":kv["device_fingerprint"],
  "current_installer_version":kv.get("current_installer_version",""),
  "target_installer_version":kv.get("target_installer_version","0.24.0-phase24"),
  "current_erp_image_digest":kv.get("current_erp_image_digest",""),
  "target_erp_image_digest":kv.get("target_erp_image_digest",""),
  "current_addon_manifest_digest":kv.get("current_addon_manifest_digest",""),
  "target_addon_manifest_digest":kv.get("target_addon_manifest_digest",""),
  "minimum_supported_source_version":kv.get("minimum_supported_source_version","0.15.0"),
  "update_path":kv.get("update_path","full"),
  "source_database_uuid":kv.get("source_database_uuid",""),
  "postgresql_compatibility":kv.get("postgresql_compatibility","16"),
  "architecture":kv.get("architecture","arm64"),
  "os_constraints":kv.get("os_constraints","linux"),
  "container_runtime_constraints":kv.get("container_runtime_constraints","docker"),
  "required_free_disk_bytes":int(kv.get("required_free_disk_bytes","1073741824")),
  "estimated_temporary_disk_bytes":int(kv.get("estimated_temporary_disk_bytes","2147483648")),
  "required_ram_bytes":int(kv.get("required_ram_bytes","2147483648")),
  "backup_requirement":"mandatory_verified_phase16",
  "payload_inventory":json.loads(kv.get("payload_inventory","[]")),
  "official_addon_inventory":json.loads(kv.get("official_addon_inventory","[]")),
  "custom_addon_inventory":json.loads(kv.get("custom_addon_inventory","[]")),
  "migration_inventory":json.loads(kv.get("migration_inventory","[]")),
  "rollback_assets":json.loads(kv.get("rollback_assets","[]")),
  "release_notes_reference":"release/RELEASE_NOTES.md",
  "known_warnings":json.loads(kv.get("known_warnings","[]")),
  "required_confirmations":["APPLY OFFLINE BUNDLE"],
  "issued_at":now,
  "not_before":kv.get("not_before",now),
  "apply_expiry":kv.get("apply_expiry",""),
  "signer_purpose":"bundle_manifest",
  "trust_root_id":kv.get("trust_root_id","offline-root-v1"),
  "replay_policy":"inspect_import_repeatable_apply_once",
  "maximum_successful_apply_count":1,
  "reconciliation_policy":"explicit_later_non_blocking",
  "entitlement_metadata":json.loads(kv.get("entitlement_metadata",'{"capabilities":["product_updates","offline_update_bundle"]}')),
  "no_business_data_declaration":True,
  "no_secret_declaration":True,
  "compression_format":kv.get("compression_format","tar.zst"),
  "network_required_during_apply":False,
  "production_slot_mutation_allowed":False,
  "license_rebind_allowed":False,
  "device_replacement_allowed":False,
}
# Canonical digest of unsigned body
canon=json.dumps(doc, sort_keys=True, separators=(",",":")).encode()
doc["canonical_manifest_digest"]="sha256:"+hashlib.sha256(canon).hexdigest()
open(os.environ["SOVIEZ_OUT"],"w").write(json.dumps(doc, indent=2, sort_keys=True)+"\n")
PY
}

soviez_offline_bundle_write_authorization() {
  local out="$1"
  shift
  SOVIEZ_OUT="$out" python3 - "$@" <<'PY'
import json, os, sys, datetime
kv={}
for a in sys.argv[1:]:
  if "=" in a:
    k,v=a.split("=",1); kv[k]=v
now=kv.get("not_before") or datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
doc={
  "schema_version":"soviez.offline_authorization.v1",
  "authorization_id":kv["authorization_id"],
  "issuance_id":kv.get("issuance_id",""),
  "account_id":kv.get("account_id",""),
  "license_id":kv["license_id"],
  "entitlement_grant_ids":json.loads(kv.get("entitlement_grant_ids","[]")),
  "environment_id":kv["environment_id"],
  "device_fingerprint":kv["device_fingerprint"],
  "current_installer_version":kv.get("current_installer_version",""),
  "current_erp_digest":kv.get("current_erp_digest",""),
  "approved_target_installer_version":kv.get("approved_target_installer_version","0.24.0-phase24"),
  "approved_target_erp_digest":kv.get("approved_target_erp_digest",""),
  "bundle_id":kv["bundle_id"],
  "bundle_type":"full",
  "issuance_reason":kv.get("issuance_reason","customer_request"),
  "not_before":now,
  "authorization_expiry":kv.get("authorization_expiry",""),
  "apply_expiry":kv.get("apply_expiry",""),
  "successful_apply_limit":1,
  "import_inspection_replay_policy":"allowed",
  "revocation_state_at_issuance":kv.get("revocation_state_at_issuance","none"),
  "signer_purpose":"authorization",
  "signer_key_id":kv.get("signer_key_id","authorization-v1"),
  "trust_root_id":kv.get("trust_root_id","offline-root-v1"),
  "result_reconciliation_policy":"explicit_later_non_blocking",
  "offline_apply_allowed":True,
  "network_required_during_apply":False,
  "production_slot_mutation_allowed":False,
  "license_rebind_allowed":False,
  "device_replacement_allowed":False,
}
open(os.environ["SOVIEZ_OUT"],"w").write(json.dumps(doc, indent=2, sort_keys=True)+"\n")
PY
}

soviez_offline_bundle_build_dir() {
  # Build layout under $1 from env SOVIEZ_OB_* variables / args
  local work="$1"
  local bundle_id="${2:?bundle_id}"
  local license_id="${3:?license}"
  local env_id="${4:?env}"
  local device_fp="${5:?device}"
  local target_digest="${6:?digest}"
  local current_digest="${7:-}"
  local auth_id="${8:-auth-${bundle_id}}"
  local issuance_id="${9:-iss-${bundle_id}}"
  local apply_expiry="${10:-}"
  local auth_expiry="${11:-}"

  rm -rf "$work"
  mkdir -p "$work"/{authorization,trust,compatibility,payload/{installer,oci,addons,migrations,rollback},checksums,release,docs}

  if [[ -z "$apply_expiry" ]]; then
    apply_expiry="$(python3 - <<'PY'
from datetime import datetime, timedelta, timezone
print((datetime.now(timezone.utc)+timedelta(days=30)).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
)"
  fi
  if [[ -z "$auth_expiry" ]]; then
    auth_expiry="$(python3 - <<'PY'
from datetime import datetime, timedelta, timezone
print((datetime.now(timezone.utc)+timedelta(days=7)).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
)"
  fi

  # Minimal OCI layout fixture (real digest recorded)
  mkdir -p "$work/payload/oci/blobs/sha256"
  local layer_blob oci_digest
  layer_blob="$work/payload/oci/blobs/sha256/placeholder"
  printf 'soviez-phase23-oci-layer\n' > "$layer_blob"
  oci_digest="sha256:$(soviez_offline_bundle_sha256_file "$layer_blob")"
  mv "$layer_blob" "$work/payload/oci/blobs/sha256/${oci_digest#sha256:}"
  printf '{"imageLayoutVersion":"1.0.0"}\n' > "$work/payload/oci/oci-layout"
  printf '{"schemaVersion":2,"mediaType":"application/vnd.oci.image.index.v1+json","manifests":[{"mediaType":"application/vnd.oci.image.manifest.v1+json","digest":"%s","size":1}]}\n' \
    "${target_digest:-$oci_digest}" > "$work/payload/oci/index.json"

  # Official addon stub
  mkdir -p "$work/payload/addons/official"
  printf '{"name":"soviez_base","version":"1.0.0","classification":"official","digest":"sha256:aaa"}\n' \
    > "$work/payload/addons/official/manifest.json"

  printf '# Offline apply\nImport, verify, plan, backup, apply via Phase 15.\n' > "$work/docs/OFFLINE_APPLY.md"
  printf '# Recovery\nUse Phase 16 restore / Phase 15 rollback.\n' > "$work/docs/RECOVERY.md"
  printf '# Reconciliation\nExplicit later upload of signed receipt.\n' > "$work/docs/RECONCILIATION.md"
  printf 'Phase 23 offline update notes\n' > "$work/release/RELEASE_NOTES.md"
  printf '{"release":"0.24.0-phase24","channel":"stable"}\n' > "$work/release/release.json"

  local payload_inv
  payload_inv="$(printf '[{"path":"payload/oci","digest":"%s","kind":"oci"}]' "${target_digest:-$oci_digest}")"

  soviez_offline_bundle_write_authorization "$work/authorization/authorization.json" \
    "authorization_id=$auth_id" \
    "issuance_id=$issuance_id" \
    "license_id=$license_id" \
    "environment_id=$env_id" \
    "device_fingerprint=$device_fp" \
    "bundle_id=$bundle_id" \
    "current_erp_digest=$current_digest" \
    "approved_target_erp_digest=${target_digest:-$oci_digest}" \
    "apply_expiry=$apply_expiry" \
    "authorization_expiry=$auth_expiry" \
    'entitlement_grant_ids=["grant-product-updates","grant-offline-bundle"]'

  soviez_offline_bundle_write_manifest "$work/bundle.json" \
    "bundle_id=$bundle_id" \
    "authorization_id=$auth_id" \
    "issuance_id=$issuance_id" \
    "license_id=$license_id" \
    "environment_id=$env_id" \
    "device_fingerprint=$device_fp" \
    "current_erp_image_digest=$current_digest" \
    "target_erp_image_digest=${target_digest:-$oci_digest}" \
    "apply_expiry=$apply_expiry" \
    "payload_inventory=$payload_inv" \
    'official_addon_inventory=[{"name":"soviez_base","version":"1.0.0"}]' \
    'entitlement_metadata={"capabilities":["product_updates","offline_update_bundle"],"quantity_consumed":0}'

  printf '{"schema":"soviez.compatibility.v1","ok":true}\n' > "$work/compatibility/compatibility.json"
  printf '{"schema":"soviez.trust_roots.v1","trust_package_id":"tp-1","sequence":1,"root_ids":["offline-root-v1"]}\n' \
    > "$work/trust/roots.json"
  printf '{"schema":"soviez.revocations.v1","entries":[],"sequence":1}\n' > "$work/trust/revocations.json"

  # Sign all purpose-bound objects
  for purpose_path in \
    "authorization:$work/authorization/authorization.json" \
    "bundle_manifest:$work/bundle.json" \
    "release:$work/release/release.json" \
    "trust_root:$work/trust/roots.json" \
    "revocation:$work/trust/revocations.json"
  do
    local purpose="${purpose_path%%:*}"
    local fpath="${purpose_path#*:}"
    soviez_offline_trust_sign_json_file "$purpose" "$fpath" || return 1
  done

  # Checksums (exclude .sig from content hash list order)
  # Avoid find|sort|while SIGPIPE under pipefail on BSD/macOS.
  local _sums_list
  _sums_list="$(mktemp "${TMPDIR:-/tmp}/soviez-sums.XXXXXX")"
  (
    set +o pipefail 2>/dev/null || true
    cd "$work" || exit 1
    find . -type f ! -name '*.sig' ! -path './checksums/*' | LC_ALL=C sort > "$_sums_list" || true
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      printf '%s  %s\n' "$(soviez_offline_bundle_sha256_file "$f")" "${f#./}"
    done < "$_sums_list"
  ) > "$work/checksums/SHA256SUMS"
  rm -f "$_sums_list"
  # SHA256SUMS is not JSON — sign raw bytes
  local body sig
  body="$(cat "$work/checksums/SHA256SUMS")"
  sig="$(soviez_offline_trust_sign_payload bundle_manifest "$body")" || return 1
  printf '%s\n' "$sig" > "$work/checksums/SHA256SUMS.sig"

  # Secret scan
  if grep -RIlE 'BEGIN (PRIVATE|RSA|OPENSSH) KEY|auths"|registry_password|docker_login' "$work" >/dev/null 2>&1; then
    soviez_offline_die OFFLINE_BUNDLE_PAYLOAD_CORRUPT "Secret/credential pattern in bundle workspace"
  fi
}

soviez_offline_bundle_pack() {
  local work="$1" out_archive="$2"
  local parent base tmp_tar use_gnu=0
  parent="$(dirname "$work")"
  base="$(basename "$work")"
  mkdir -p "$(dirname "$out_archive")"
  if tar --help 2>&1 | grep -q -- '--sort=name'; then
    use_gnu=1
  fi
  tmp_tar="$(mktemp "${TMPDIR:-/tmp}/soviez-bundle.XXXXXX").tar"
  (
    cd "$parent" || exit 1
    if [[ "$use_gnu" == "1" ]]; then
      tar --sort=name --owner=0 --group=0 --numeric-owner --mtime='UTC 2020-01-01' -cf "$tmp_tar" "$base"
    else
      find "$base" -exec touch -t 202001010000 {} + 2>/dev/null || true
      tar -cf "$tmp_tar" "$base"
    fi
  )
  if command -v zstd >/dev/null 2>&1; then
    zstd -q -f -19 -T0 -o "$out_archive" "$tmp_tar"
  else
    # Rename to .tar.gz path expected by caller when zstd absent
    gzip -cf "$tmp_tar" > "${out_archive%.tar.zst}.tar.gz" 2>/dev/null || gzip -cf "$tmp_tar" > "$out_archive"
  fi
  rm -f "$tmp_tar"
}

soviez_offline_bundle_issue_local() {
  # Certification/local issuance helper (export worker substitute for disposable lab)
  local bundle_id="$1" license_id="$2" env_id="$3" device_fp="$4" target_digest="$5"
  local current_digest="${6:-}"
  soviez_offline_bundle_paths_init
  soviez_offline_trust_paths_init
  local work out
  work="$SOVIEZ_OFFLINE_BUNDLE_ISSUANCE_DIR/$bundle_id/tree"
  out="$SOVIEZ_OFFLINE_BUNDLE_ISSUANCE_DIR/$bundle_id/bundle.tar.zst"
  [[ -n "${SOVIEZ_OFFLINE_BUNDLE_FORCE_TGZ:-}" ]] && out="$SOVIEZ_OFFLINE_BUNDLE_ISSUANCE_DIR/$bundle_id/bundle.tar.gz"
  soviez_offline_bundle_build_dir "$work" "$bundle_id" "$license_id" "$env_id" "$device_fp" \
    "$target_digest" "$current_digest" || return 1
  soviez_offline_bundle_pack "$work" "$out" || return 1
  printf '%s\n' "$out"
}
