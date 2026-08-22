# shellcheck shell=bash
# Named release catalog (trusted metadata; not Docker tags).

soviez_release_catalog_path() {
  local root="${SOVIEZ_SH_ROOT:-}"
  local candidates=(
    "${root}/share/releases/catalog.json"
    "/opt/soviez/platform/current/share/releases/catalog.json"
    "$(cd "$(dirname "${BASH_SOURCE[0]:-}")/../../share/releases" 2>/dev/null && pwd)/catalog.json"
  )
  local c
  for c in "${candidates[@]}"; do
    [[ -f "$c" ]] && { printf '%s\n' "$c"; return 0; }
  done
  return 1
}

soviez_release_catalog_load() {
  local path
  path="$(soviez_release_catalog_path 2>/dev/null || true)"
  [[ -n "$path" && -f "$path" ]] || return 1
  cat "$path"
}

soviez_release_immutability_assert() {
  local name="$1" digest="$2" store="${SOVIEZ_RELEASE_LEDGER:-/var/soviez/releases/ledger.json}"
  mkdir -p "$(dirname "$store")"
  python3 - "$store" "$name" "$digest" <<'PY'
import json, os, sys
store, name, digest = sys.argv[1:4]
ledger = {}
if os.path.isfile(store):
    ledger = json.load(open(store, encoding="utf-8"))
prev = ledger.get(name)
if prev and prev != digest:
    print(f"[error] release immutability violation: {name} was {prev}, attempted {digest}", file=sys.stderr)
    sys.exit(1)
ledger[name] = digest
json.dump(ledger, open(store, "w"), indent=2)
PY
}

soviez_release_resolve_by_name() {
  local name="$1"
  local catalog path
  path="$(soviez_release_catalog_path 2>/dev/null || true)"
  [[ -n "$path" ]] || return 1
  python3 - "$path" "$name" <<'PY'
import json, sys
cat = json.load(open(sys.argv[1], encoding="utf-8"))
name = sys.argv[2]
for r in cat.get("releases", []):
    if r.get("release_name") == name or r.get("release_id") == name:
        print(json.dumps(r))
        break
else:
    sys.exit(1)
PY
}
