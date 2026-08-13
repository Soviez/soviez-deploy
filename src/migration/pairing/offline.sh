# shellcheck shell=bash

soviez_migration_offline_export() {
  local kind="$1" id="$2" output="$3"
  [[ -n "$output" ]] || soviez_migration_die MIGRATION_NOT_FOUND "output path required"
  local src
  case "$kind" in
    bootstrap) src="$(soviez_migration_bootstrap_dir "$id")/object.json" ;;
    pair) src="$(soviez_migration_pair_dir "$id")/object.json" ;;
    readiness) src="$(soviez_migration_readiness_dir "$id")/object.json" ;;
    discovery) src="$(soviez_migration_discovery_dir "$id")/object.json" ;;
    *) soviez_migration_die MIGRATION_NOT_FOUND "Unknown offline kind" ;;
  esac
  [[ -f "$src" ]] || soviez_migration_die MIGRATION_NOT_FOUND "Missing object for export"
  mkdir -p "$(dirname "$output")"
  # Quarantine package: public metadata only — strip any accidental private key refs
  SOVIEZ_S="$src" SOVIEZ_O="$output" python3 - <<'PY'
import json, os, datetime, hashlib
doc=json.load(open(os.environ["SOVIEZ_S"]))
# Never export private keys
for k in list(doc.keys()):
  if "private" in k.lower() or k.endswith("_key"):
    doc.pop(k, None)
refs=doc.get("trust_certificate_refs") or {}
if isinstance(refs, dict):
  refs.pop("private", None)
  doc["trust_certificate_refs"]=refs
pkg={
  "schema_version": "soviez.migration.offline.v1",
  "kind": "export",
  "exported_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
  "expires_at": doc.get("expires_at") or doc.get("pair_expires_at") or "",
  "payload": doc,
  "payload_sha256": hashlib.sha256(json.dumps(doc, sort_keys=True, separators=(",",":")).encode()).hexdigest(),
  "data_transfer_authorized": False,
  "permanent_private_key_exported": False,
}
open(os.environ["SOVIEZ_O"],"w").write(json.dumps(pkg, indent=2))
PY
  # Sign package envelope
  soviez_migration_sign_object_file "$output"
  printf '%s\n' "$output"
}

soviez_migration_offline_import() {
  local path="$1"
  [[ -f "$path" ]] || soviez_migration_die MIGRATION_NOT_FOUND "Import path missing"
  # Quarantine then verify
  soviez_migration_paths_init
  local qdir qpath
  qdir="$SOVIEZ_MIG_OFFLINE_DIR/quarantine/$(openssl rand -hex 4)"
  mkdir -p "$qdir"
  cp "$path" "$qdir/package.json"
  qpath="$qdir/package.json"
  if ! soviez_migration_verify_object_signature "$qpath"; then
    # Phase 24: unsigned offline migration packages require disposable test bypass
    # (TEST_MODE + disposable env + not production). Flag alone is insufficient.
    local allow_unsigned=0
    if [[ "${SOVIEZ_MIG_ALLOW_UNSIGNED_OFFLINE_TEST:-0}" == "1" ]]; then
      if declare -F soviez_security_test_bypass_allowed >/dev/null 2>&1; then
        if soviez_security_test_bypass_allowed; then
          allow_unsigned=1
        fi
      elif [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
        # Pre-security-module fallback: still require TEST_MODE
        allow_unsigned=1
      fi
    fi
    if [[ "$allow_unsigned" != "1" ]]; then
      soviez_migration_die MIGRATION_PAIR_SIGNATURE_INVALID "Offline package signature invalid"
    fi
  fi
  local expires kind
  expires="$(soviez_json_get "$(cat "$qpath")" expires_at)"
  if [[ -n "$expires" ]] && soviez_migration_is_expired "$expires"; then
    soviez_migration_die MIGRATION_PAIR_EXPIRED "Offline package expired"
  fi
  # Replay protection: hash store
  local h
  h="$(openssl dgst -sha256 "$qpath" | awk '{print $NF}')"
  local seen="$SOVIEZ_MIG_OFFLINE_DIR/seen/$h"
  if [[ -f "$seen" ]]; then
    soviez_migration_die MIGRATION_PAIR_REPLAY_DENIED "Offline package replay denied"
  fi
  mkdir -p "$(dirname "$seen")"
  date -u +%Y-%m-%dT%H:%M:%SZ > "$seen"
  # Import payload into appropriate store
  SOVIEZ_Q="$qpath" SOVIEZ_ROOT_MIG="$SOVIEZ_MIG_ROOT" python3 - <<'PY'
import json, os, pathlib
pkg=json.load(open(os.environ["SOVIEZ_Q"]))
payload=pkg.get("payload") or {}
root=pathlib.Path(os.environ["SOVIEZ_ROOT_MIG"])
schema=payload.get("schema_version") or ""
if "bootstrap" in schema:
  bid=payload["bootstrap_id"]; d=root/"bootstraps"/bid; d.mkdir(parents=True, exist_ok=True)
  (d/"object.json").write_text(json.dumps(payload, separators=(",",":")))
elif "pair" in schema or "migration_pair" in schema:
  pid=payload["migration_pair_id"]; d=root/"pairs"/pid; d.mkdir(parents=True, exist_ok=True)
  (d/"object.json").write_text(json.dumps(payload, separators=(",",":")))
elif "readiness" in schema:
  rid=payload["report_id"]; d=root/"readiness"/rid; d.mkdir(parents=True, exist_ok=True)
  (d/"object.json").write_text(json.dumps(payload, separators=(",",":")))
elif "discovery" in schema:
  did=payload["discovery_id"]; d=root/"discoveries"/did; d.mkdir(parents=True, exist_ok=True)
  (d/"object.json").write_text(json.dumps(payload, separators=(",",":")))
else:
  raise SystemExit("unknown payload")
print(json.dumps({"imported": True, "schema_version": schema}, separators=(",", ":")))
PY
}
