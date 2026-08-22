# shellcheck shell=bash

soviez_cmd_releases_run() {
  soviez_release_catalog_load >/dev/null 2>&1 || {
    echo "[error] release catalog unavailable" >&2
    return 1
  }
  local path
  path="$(soviez_release_catalog_path)"
  printf '%-20s %-16s %-12s\n' "RELEASE" "CHANNEL" "STATUS"
  python3 - "$path" <<'PY'
import json, sys
cat = json.load(open(sys.argv[1], encoding="utf-8"))
for r in cat.get("releases", []):
    print(f"{r.get('release_name','?'):<20} {r.get('channel','?'):<16} {r.get('status','?'):<12}")
PY
}
