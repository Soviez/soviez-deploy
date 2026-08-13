# shellcheck shell=bash

soviez_backup_verify_level1() {
  # Level 1 archive integrity -> VERIFIED
  # Args: backup_id
  local backup_id="$1"
  local obj prod_id bdir man cs map tmp="" now
  soviez_backup_paths_init
  obj="$(soviez_backup_read_object "$backup_id")"
  prod_id="$(soviez_json_get "$obj" production_id)"
  bdir="$(soviez_backup_dir "$prod_id" "$backup_id")"
  man="$bdir/manifest.json"
  cs="$bdir/checksums.txt"

  [[ -d "$bdir" ]] || soviez_backup_die BACKUP_NOT_FOUND "Backup directory missing"
  [[ -f "$man" ]] || soviez_backup_die BACKUP_MANIFEST_FAILED "Missing manifest"
  soviez_backup_manifest_verify "$man"
  [[ -f "$cs" ]] || soviez_backup_die BACKUP_CHECKSUM_MISMATCH "Missing checksums"

  # Map checksum names to stored artifacts (prefer exact stored form, including .enc)
  map="$(SOVIEZ_D="$bdir" SOVIEZ_CS="$(cat "$cs")" python3 -c '
import json, os
d = os.environ["SOVIEZ_D"]
names = []
for line in os.environ["SOVIEZ_CS"].splitlines():
  if "=" in line:
    names.append(line.split("=", 1)[0])
candidates = {
  "db": ["db.dump.enc", "db.dump"],
  "filestore": [
    "filestore.tar.zst.enc", "filestore.tar.gz.enc",
    "filestore.tar.zst", "filestore.tar.gz", "filestore.tar",
  ],
  "manifest": ["manifest.json"],
}
mp = {}
for n in names:
  for c in candidates.get(n, [n]):
    p = os.path.join(d, c)
    if os.path.isfile(p):
      mp[n] = p
      break
print(json.dumps(mp))
')"
  soviez_backup_checksums_verify "$cs" "$map"

  # Encrypted envelope readable when passphrase configured
  if [[ -f "$bdir/db.dump.enc" ]] && soviez_backup_encryption_passphrase_ready; then
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/soviez-bk-verify.XXXXXX")"
    chmod 700 "$tmp"
    if ! soviez_backup_decrypt_file "$bdir/db.dump.enc" "$tmp/envelope-check.dump" 2>/dev/null; then
      rm -rf "$tmp"
      soviez_backup_die BACKUP_ENCRYPTION_KEY_INVALID "Encrypted database envelope unreadable"
    fi
    rm -rf "$tmp"
  fi

  if declare -F soviez_utc_now >/dev/null 2>&1; then now="$(soviez_utc_now)"; else now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"; fi
  obj="$(soviez_backup_patch_object "$prod_id" "$backup_id" \
    "{\"verification_status\":\"VERIFIED\",\"verification_at\":\"$now\",\"status\":\"verified\"}")"
  soviez_backup_inventory_upsert "$obj"
  SOVIEZ_BID="$backup_id" python3 -c '
import json, os
print(json.dumps({"ok": True, "code": "BACKUP_VERIFIED", "backup_id": os.environ["SOVIEZ_BID"],
                  "verification_status": "VERIFIED"}, separators=(",", ":")))
'
}
