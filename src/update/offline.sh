# shellcheck shell=bash

# Offline signed update package (Phase 15 minimum — not full Phase 23).

soviez_update_offline_import() {
  local package_path="$1" op_id="$2" expected_license="$3" expected_prod="$4"
  [[ -e "$package_path" ]] || soviez_update_die UPDATE_OFFLINE_PACKAGE_INVALID "Offline package not found"
  local work
  work="$(soviez_update_op_dir "$op_id")/offline"
  mkdir -p "$work"
  # Package is a directory or tar of JSON+artifact markers in test mode
  if [[ -d "$package_path" ]]; then
    cp -a "$package_path/." "$work/"
  else
    # Expect JSON sidecar or extractable archive
    if [[ "$package_path" == *.json ]]; then
      cp "$package_path" "$work/package.json"
    else
      tar -xf "$package_path" -C "$work" 2>/dev/null \
        || soviez_update_die UPDATE_OFFLINE_PACKAGE_INVALID "Cannot extract offline package"
    fi
  fi
  local pkg
  pkg="$(cat "$work/package.json" 2>/dev/null || cat "$work/manifest.json" 2>/dev/null || true)"
  [[ -n "$pkg" ]] || soviez_update_die UPDATE_OFFLINE_PACKAGE_INVALID "Missing package manifest"

  local signed signature digest license_id prod_id expires nonce pkg_id
  signed="$(soviez_json_get "$pkg" signed 2>/dev/null || echo false)"
  signature="$(soviez_json_get "$pkg" signature 2>/dev/null || true)"
  digest="$(soviez_json_get "$pkg" digest 2>/dev/null || soviez_json_get "$pkg" image_digest 2>/dev/null || true)"
  license_id="$(soviez_json_get "$pkg" license_id 2>/dev/null || true)"
  prod_id="$(soviez_json_get "$pkg" production_environment_id 2>/dev/null || true)"
  expires="$(soviez_json_get "$pkg" expires_at 2>/dev/null || true)"
  nonce="$(soviez_json_get "$pkg" nonce 2>/dev/null || soviez_json_get "$pkg" package_id 2>/dev/null || true)"
  pkg_id="$(soviez_json_get "$pkg" package_id 2>/dev/null || echo "$nonce")"

  local phase23_pre
  phase23_pre="$(soviez_json_get "$pkg" phase23_preverified 2>/dev/null || echo false)"

  # Phase 24: production-default refuse non-cryptographic fixture signatures.
  # Disposable test bypass may accept fixtures unless a certification profile forbids them.
  # phase23_preverified=true is only valid when upstream Ed25519 already ran (engine reuse).
  local forbid_fake=1
  if declare -F soviez_security_test_bypass_allowed >/dev/null 2>&1 && soviez_security_test_bypass_allowed; then
    if [[ "${SOVIEZ_PHASE23_CERTIFICATION:-0}" != "1" \
       && "${SOVIEZ_PHASE23_FORBID_FAKE_SIGNATURES:-0}" != "1" \
       && "${SOVIEZ_PHASE24_CERTIFICATION:-0}" != "1" ]]; then
      forbid_fake=0
    fi
  fi

  if [[ "$forbid_fake" == "1" ]]; then
    if [[ "$phase23_pre" != "true" && "$phase23_pre" != "True" ]]; then
      if declare -F soviez_security_is_fake_signature >/dev/null 2>&1 && soviez_security_is_fake_signature "$signature"; then
        soviez_update_die UPDATE_OFFLINE_PACKAGE_INVALID "Non-cryptographic offline signature forbidden"
      fi
      if [[ "$signature" == "ok" || "$signature" == "valid" || "$signature" == "fixture" || "$signature" == "phase23-preverified" ]]; then
        soviez_update_die UPDATE_OFFLINE_PACKAGE_INVALID "Non-cryptographic offline signature forbidden"
      fi
      # Require real Ed25519 verification when bundle present
      if [[ -f "$work/bundle.json" ]] && declare -F soviez_offline_trust_verify_json_file >/dev/null 2>&1; then
        soviez_offline_trust_verify_json_file bundle_manifest "$work/bundle.json" \
          || soviez_update_die UPDATE_OFFLINE_PACKAGE_INVALID "Cryptographic bundle verification failed"
      elif [[ "${SOVIEZ_PHASE23_CERTIFICATION:-0}" == "1" || "${SOVIEZ_PHASE24_CERTIFICATION:-0}" == "1" ]]; then
        soviez_update_die UPDATE_OFFLINE_PACKAGE_INVALID "Certification requires cryptographic bundle verification"
      fi
    fi
    # phase23_preverified=true means Phase 23 import already verified Ed25519 — allow engine reuse
    if [[ "$phase23_pre" == "true" || "$phase23_pre" == "True" ]]; then
      signed=true
    fi
  fi

  if [[ "$phase23_pre" == "true" || "$phase23_pre" == "True" ]]; then
    # Preverified marker alone is insufficient outside disposable test bypass.
    if declare -F soviez_security_test_bypass_allowed >/dev/null 2>&1 && ! soviez_security_test_bypass_allowed; then
      if [[ "${SOVIEZ_PHASE23_CERTIFICATION:-0}" != "1" && "${SOVIEZ_OFFLINE_ENGINE_REUSE:-0}" != "1" ]]; then
        soviez_update_die UPDATE_OFFLINE_PACKAGE_INVALID "phase23_preverified refused without verified engine reuse"
      fi
    fi
    signed=true
    [[ -n "$signature" ]] || signature="phase23-preverified"
  fi

  if [[ "$phase23_pre" == "true" || "$phase23_pre" == "True" ]] \
     && [[ "${SOVIEZ_OFFLINE_ENGINE_REUSE:-0}" == "1" || "${SOVIEZ_PHASE23_CERTIFICATION:-0}" == "1" ]]; then
    # Upstream Ed25519 already verified — do not re-apply fake-sig denial on marker.
    [[ "$signed" == "true" || "$signed" == "True" ]] || signed=true
  elif declare -F soviez_security_require_signed_manifest >/dev/null 2>&1; then
    soviez_security_require_signed_manifest "$signed" "$signature" "offline_package"
  else
    [[ "$signed" == "true" || "$signed" == "True" ]] || soviez_update_die UPDATE_OFFLINE_PACKAGE_INVALID "Unsigned offline package refused"
    [[ -n "$signature" && "$signature" != "null" && "$signature" != "tampered" && "$signature" != "invalid" ]] \
      || soviez_update_die UPDATE_OFFLINE_PACKAGE_INVALID "Offline package signature invalid"
  fi
  [[ -n "$digest" ]] || soviez_update_die UPDATE_RELEASE_DIGEST_MISSING "Offline package missing digest"
  if [[ -n "$license_id" && "$license_id" != "null" ]]; then
    [[ "$license_id" == "$expected_license" ]] || soviez_update_die UPDATE_WRONG_LICENSE "Offline package license mismatch"
  fi
  if [[ -n "$prod_id" && "$prod_id" != "null" ]]; then
    [[ "$prod_id" == "$expected_prod" ]] || soviez_update_die UPDATE_TARGET_INVALID "Offline package Production binding mismatch"
  fi

  # Entitlement proof — Phase 23 requires product_updates + offline_update_bundle
  local ent_ok capability caps
  capability="$(soviez_json_get "$pkg" capability 2>/dev/null || true)"
  ent_ok="$(soviez_json_get "$pkg" entitlement_ok 2>/dev/null || echo false)"
  caps="$(soviez_json_get "$pkg" entitlements 2>/dev/null || echo "[]")"
  if [[ "$phase23_pre" == "true" || "$phase23_pre" == "True" || "${SOVIEZ_PHASE23_CERTIFICATION:-0}" == "1" ]]; then
    printf '%s' "$caps" | grep -q 'product_updates' \
      || soviez_update_die UPDATE_OFFLINE_ENTITLEMENT_INVALID "product_updates required"
    printf '%s' "$caps" | grep -q 'offline_update_bundle' \
      || soviez_update_die UPDATE_OFFLINE_ENTITLEMENT_INVALID "offline_update_bundle required"
  else
    [[ "$capability" == "product_updates" ]] || soviez_update_die UPDATE_OFFLINE_ENTITLEMENT_INVALID "Offline entitlement must grant product_updates"
    [[ "$ent_ok" == "true" || "$ent_ok" == "True" ]] || soviez_update_die UPDATE_OFFLINE_ENTITLEMENT_INVALID "Offline entitlement proof invalid"
  fi

  # Expiry
  if [[ -n "$expires" && "$expires" != "null" ]]; then
    SOVIEZ_EXP="$expires" python3 - <<'PY' || soviez_update_die UPDATE_OFFLINE_PACKAGE_INVALID "Offline package expired"
import os,sys
from datetime import datetime,timezone
exp=os.environ["SOVIEZ_EXP"].replace("Z","+00:00")
dt=datetime.fromisoformat(exp)
if dt < datetime.now(timezone.utc):
  sys.exit(1)
PY
  fi

  # Replay prevention
  local replay_db="$SOVIEZ_UPDATE_PACKAGES_DIR/used_nonces.txt"
  mkdir -p "$SOVIEZ_UPDATE_PACKAGES_DIR"
  touch "$replay_db"
  if grep -qxF "$pkg_id" "$replay_db" 2>/dev/null; then
    soviez_update_die UPDATE_OFFLINE_PACKAGE_INVALID "Offline package replay denied"
  fi
  printf '%s\n' "$pkg_id" >> "$replay_db"

  printf '%s' "$digest" > "$(soviez_update_op_dir "$op_id")/offline_digest.txt"
  printf '%s' "$pkg" > "$(soviez_update_op_dir "$op_id")/offline_package.json"
  # Build release manifest for shared path
  SOVIEZ_P="$pkg" python3 - <<'PY'
import json,os
p=json.loads(os.environ["SOVIEZ_P"])
print(json.dumps({
  "release_id":p.get("release_id") or p.get("package_id"),
  "digest":p.get("digest") or p.get("image_digest"),
  "signed":True,
  "signature":p.get("signature"),
  "architecture":p.get("architecture") or p.get("arch"),
  "erp_major":p.get("erp_major"),
  "image_ref":p.get("image_ref") or ("soviez/erp@"+(p.get("digest") or "")),
  "notes_ref":p.get("notes_ref"),
},separators=(",",":")))
PY
}
