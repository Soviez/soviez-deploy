# shellcheck shell=bash

soviez_migration_authorization_export() {
  local auth_id="$1"
  local out="${2:-}"
  local authf
  authf="$(soviez_migration_p20_auth_dir "$auth_id")/authorization.json"
  [[ -f "$authf" ]] || soviez_migration_die MIGRATION_AUTHORIZATION_REQUIRED "missing"
  local pkg_id
  pkg_id="pkg-$auth_id"
  local pkg
  pkg="$(SOVIEZ_A="$(cat "$authf")" SOVIEZ_P="$pkg_id" python3 - <<'PY'
import json,os,hashlib,time
auth=json.loads(os.environ["SOVIEZ_A"])
# Offline package requires already-committed authorization
assert auth.get("transaction_status")=="committed"
pkg={
 "schema":"soviez.migration_authorization_offline_package.v1",
 "package_id":os.environ["SOVIEZ_P"],
 "authorization":auth,
 "issued_at":time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime()),
 "expires_at":time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime(time.time()+3600)),
 "no_private_keys":True,
}
pkg["public_signature"]=hashlib.sha256(json.dumps(auth,sort_keys=True,separators=(",",":")).encode()).hexdigest()
print(json.dumps(pkg,separators=(",",":")))
PY
)"
  mkdir -p "$SOVIEZ_MIG_ROOT/offline_packages"
  printf '%s\n' "$pkg" > "$SOVIEZ_MIG_ROOT/offline_packages/$pkg_id.json"
  if [[ -n "$out" ]]; then
    printf '%s\n' "$pkg" > "$out"
  fi
  printf '%s\n' "$pkg"
}

soviez_migration_authorization_import() {
  local path="$1"
  [[ -f "$path" ]] || soviez_migration_die MIGRATION_AUTHORIZATION_REQUIRED "package path missing"
  local pkg_id="" auth_id="" _line
  while IFS= read -r _line; do
    if [[ -z "$pkg_id" ]]; then pkg_id="$_line"; else auth_id="$_line"; fi
  done < <(python3 - "$path" <<'PY'
import json, sys
pkg = json.load(open(sys.argv[1]))
auth = pkg.get("authorization") or {}
print(pkg.get("package_id", ""))
print(auth.get("authorization_id", ""))
PY
)
  [[ -n "$pkg_id" && -n "$auth_id" ]] || soviez_migration_die MIGRATION_AUTHORIZATION_INVALID "package missing package_id or authorization_id"
  # expiry
  SOVIEZ_P="$(cat "$path")" python3 - <<'PY'
import json,os,sys,time
from datetime import datetime
pkg=json.loads(os.environ["SOVIEZ_P"])
exp=datetime.strptime(pkg["expires_at"],"%Y-%m-%dT%H:%M:%SZ").timestamp()
if time.time()>exp:
  print("EXPIRED"); sys.exit(25)
auth=pkg.get("authorization") or {}
if auth.get("transaction_status")!="committed":
  print("NOT_COMMITTED"); sys.exit(25)
if not pkg.get("public_signature"):
  print("UNSIGNED"); sys.exit(25)
print("OK")
PY
  # replay registry
  soviez_migration_p20_ledger offline-register --package-id "$pkg_id" --authorization-id "$auth_id"
  mkdir -p "$(soviez_migration_p20_auth_dir "$auth_id")"
  python3 -c 'import json,sys; p=json.load(open(sys.argv[1])); json.dump(p["authorization"], open(sys.argv[2],"w"), separators=(",",":"))' \
    "$path" "$(soviez_migration_p20_auth_dir "$auth_id")/authorization.json"
  # local apply
  soviez_migration_destination_binding_apply "$auth_id" >/dev/null
  soviez_migration_source_grace_apply "$auth_id" >/dev/null
  printf '{"ok":true,"authorization_id":"%s","package_id":"%s","applied":true}\n' "$auth_id" "$pkg_id"
}
