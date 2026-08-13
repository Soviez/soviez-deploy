# shellcheck shell=bash

soviez_backup_sha256_file() {
  local f="$1"
  [[ -f "$f" ]] || { printf '\n'; return 1; }
  if declare -F soviez_sha256_file >/dev/null 2>&1; then
    soviez_sha256_file "$f"
    return 0
  fi
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$f" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | awk '{print $1}'
  else
    openssl dgst -sha256 "$f" | awk '{print $NF}'
  fi
}

soviez_backup_checksums_write() {
  # Args: dest_file  then pairs of name=path as remaining args
  local dest="$1"
  shift
  mkdir -p "$(dirname "$dest")"
  : > "$dest"
  local item name path sum
  for item in "$@"; do
    name="${item%%=*}"
    path="${item#*=}"
    if [[ -f "$path" ]]; then
      sum="$(soviez_backup_sha256_file "$path")"
      printf '%s=%s\n' "$name" "$sum" >> "$dest"
    elif [[ -d "$path" ]]; then
      sum="$(find "$path" -type f -print 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do
        cat "$f"
      done | openssl dgst -sha256 2>/dev/null | awk '{print $NF}')"
      [[ -n "$sum" ]] || sum=none
      printf '%s=%s\n' "$name" "$sum" >> "$dest"
    else
      printf '%s=missing\n' "$name" >> "$dest"
    fi
  done
  chmod 600 "$dest"
}

soviez_backup_checksums_verify() {
  # Args: checksums_file map_json (name->path)
  local cs_file="$1"
  local map_json="${2:-}"
  local result map_file cs_copy
  [[ -f "$cs_file" ]] || soviez_backup_die BACKUP_CHECKSUM_MISMATCH "Missing checksums file"
  [[ -n "$map_json" ]] || map_json="{}"
  map_file="$(mktemp "${TMPDIR:-/tmp}/soviez-cs-map.XXXXXX")"
  cs_copy="$(mktemp "${TMPDIR:-/tmp}/soviez-cs-copy.XXXXXX")"
  printf '%s' "$map_json" > "$map_file"
  cp -f "$cs_file" "$cs_copy"
  result="$(SOVIEZ_CS_FILE="$cs_copy" SOVIEZ_MAP_FILE="$map_file" python3 - <<'PY'
import hashlib, json, os, sys
with open(os.environ["SOVIEZ_MAP_FILE"], encoding="utf-8") as fh:
  raw = fh.read().strip()
try:
  mp = json.loads(raw)
except json.JSONDecodeError as exc:
  print(f"map_json_error:{exc}", file=sys.stderr)
  sys.exit(3)
with open(os.environ["SOVIEZ_CS_FILE"], encoding="utf-8") as fh:
  lines = fh.read().strip().splitlines()
errors = []
for line in lines:
  if "=" not in line:
    continue
  name, expected = line.split("=", 1)
  path = mp.get(name)
  if not path or not os.path.isfile(path):
    if expected == "missing":
      continue
    errors.append(f"missing:{name}")
    continue
  h = hashlib.sha256()
  with open(path, "rb") as f:
    for chunk in iter(lambda: f.read(1024 * 1024), b""):
      h.update(chunk)
  actual = h.hexdigest()
  if actual != expected:
    errors.append(f"mismatch:{name}")
if errors:
  print(",".join(errors))
  sys.exit(3)
print("ok")
PY
)" || {
    rm -f "$map_file" "$cs_copy"
    soviez_backup_die BACKUP_CHECKSUM_MISMATCH "Checksum verification failed: ${result:-unknown}"
  }
  rm -f "$map_file" "$cs_copy"
  printf '%s\n' "$result"
}
