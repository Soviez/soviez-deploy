# shellcheck shell=bash

soviez_backup_destination_list() {
  soviez_backup_paths_init
  SOVIEZ_BACKUP_DEST_DIR="$SOVIEZ_BACKUP_DEST_DIR" python3 - <<'PY'
import json, os, glob
root = os.environ.get("SOVIEZ_BACKUP_DEST_DIR", "")
profiles = []
for path in sorted(glob.glob(os.path.join(root, "*.json"))):
  with open(path, encoding="utf-8") as fh:
    d = json.load(fh)
  profiles.append({
    "profile_id": d.get("profile_id") or os.path.splitext(os.path.basename(path))[0],
    "kind": d.get("kind"),
    "path": d.get("path"),
    "bucket": d.get("bucket"),
    "host": d.get("host"),
  })
print(json.dumps({"ok": True, "destinations": profiles}, separators=(",", ":")))
PY
}

soviez_backup_destination_show() {
  local profile_id="$1"
  [[ -n "$profile_id" ]] || soviez_backup_die BACKUP_DESTINATION_REQUIRED "profile_id required"
  soviez_backup_paths_init
  local f
  f="$(soviez_backup_dest_profile_file "$profile_id")"
  [[ -f "$f" ]] || soviez_backup_die BACKUP_DESTINATION_INVALID "Unknown destination: $profile_id"
  cat "$f"
}

soviez_backup_destination_write() {
  # Args: profile_json (must include profile_id, kind; no secrets)
  local obj="$1"
  local profile_id kind
  profile_id="$(soviez_json_get "$obj" profile_id)"
  kind="$(soviez_json_get "$obj" kind)"
  [[ -n "$profile_id" ]] || soviez_backup_die BACKUP_DESTINATION_INVALID "profile_id required"
  [[ -n "$kind" ]] || soviez_backup_die BACKUP_DESTINATION_INVALID "kind required"
  # Scrub secrets from profile JSON
  obj="$(SOVIEZ_J="$obj" python3 - <<'PY'
import json, os
forbid = {"password","secret","secret_key","access_key_secret","passphrase","private_key"}
d = json.loads(os.environ["SOVIEZ_J"])
print(json.dumps({k: v for k, v in d.items() if k.lower() not in forbid
                  and "secret" not in k.lower() and "password" not in k.lower()},
                 separators=(",", ":"), sort_keys=True))
PY
)"
  soviez_backup_paths_init
  local f
  f="$(soviez_backup_dest_profile_file "$profile_id")"
  printf '%s\n' "$obj" > "$f"
  chmod 644 "$f"
  printf '%s' "$obj"
}

soviez_backup_destination_write_secret() {
  # Args: profile_id secret_content
  local profile_id="$1" secret="$2"
  soviez_backup_paths_init
  local f
  f="$(soviez_backup_dest_secret_file "$profile_id")"
  printf '%s' "$secret" > "$f"
  chmod 600 "$f"
}

soviez_backup_destination_read_secret() {
  local profile_id="$1"
  local f
  f="$(soviez_backup_dest_secret_file "$profile_id")"
  [[ -f "$f" ]] || return 1
  cat "$f"
}

soviez_backup_destination_resolve() {
  local profile_id="${1:-local-primary}"
  local f
  soviez_backup_paths_init
  f="$(soviez_backup_dest_profile_file "$profile_id")"
  if [[ ! -f "$f" ]]; then
    # Auto-create default local profile
    if [[ "$profile_id" == "local-primary" ]]; then
      SOVIEZ_P="$profile_id" SOVIEZ_PATH="$SOVIEZ_BACKUP_DATA_DIR" python3 - <<'PY' > "$f"
import json, os
print(json.dumps({
  "profile_id": os.environ["SOVIEZ_P"],
  "kind": "local",
  "path": os.environ["SOVIEZ_PATH"],
}, separators=(",", ":")))
PY
      chmod 644 "$f"
    else
      soviez_backup_die BACKUP_DESTINATION_INVALID "Unknown destination: $profile_id"
    fi
  fi
  cat "$f"
}

soviez_backup_destination_test() {
  local profile_id="$1"
  local profile kind
  profile="$(soviez_backup_destination_resolve "$profile_id")"
  kind="$(soviez_json_get "$profile" kind)"
  case "$kind" in
    local)
      declare -F soviez_backup_local_dest_test >/dev/null 2>&1 \
        && soviez_backup_local_dest_test "$profile" \
        || soviez_backup_die BACKUP_DESTINATION_UNREACHABLE "local destination test unavailable"
      ;;
    s3)
      declare -F soviez_backup_s3_dest_test >/dev/null 2>&1 \
        && soviez_backup_s3_dest_test "$profile" \
        || soviez_backup_die BACKUP_DESTINATION_UNREACHABLE "s3 destination test unavailable"
      ;;
    sftp)
      declare -F soviez_backup_sftp_dest_test >/dev/null 2>&1 \
        && soviez_backup_sftp_dest_test "$profile" \
        || soviez_backup_die BACKUP_DESTINATION_UNREACHABLE "sftp destination test unavailable"
      ;;
    *)
      soviez_backup_die BACKUP_DESTINATION_INVALID "Unsupported destination kind: $kind"
      ;;
  esac
}
