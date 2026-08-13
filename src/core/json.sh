# shellcheck shell=bash

soviez_json_have_python() {
  command -v python3 >/dev/null 2>&1
}

soviez_json_get() {
  local json="$1"
  local key="$2"
  soviez_require_cmd python3
  SOVIEZ_JSON_INPUT="$json" SOVIEZ_JSON_KEY="$key" python3 - <<'PY'
import json, os, sys
raw = os.environ.get("SOVIEZ_JSON_INPUT", "")
key = os.environ.get("SOVIEZ_JSON_KEY", "")
try:
    data = json.loads(raw)
except json.JSONDecodeError:
    sys.exit(2)
cur = data
parts = [p for p in key.split(".") if p]
for part in parts:
    if isinstance(cur, dict) and part in cur:
        cur = cur[part]
    else:
        sys.exit(3)
if cur is None:
    print("")
elif isinstance(cur, (dict, list)):
    print(json.dumps(cur, separators=(",", ":")))
else:
    print(cur)
PY
}

soviez_json_set() {
  local file="$1"
  local key="$2"
  local value="$3"
  soviez_require_cmd python3
  SOVIEZ_JSON_FILE="$file" SOVIEZ_JSON_KEY="$key" SOVIEZ_JSON_VALUE="$value" python3 - <<'PY'
import json, os, sys
path = os.environ["SOVIEZ_JSON_FILE"]
key = os.environ["SOVIEZ_JSON_KEY"]
value_raw = os.environ.get("SOVIEZ_JSON_VALUE", "")
try:
    parsed = json.loads(value_raw)
except json.JSONDecodeError:
    parsed = value_raw
try:
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
except FileNotFoundError:
    data = {}
cur = data
parts = key.split(".")
for part in parts[:-1]:
    nxt = cur.get(part)
    if not isinstance(nxt, dict):
        nxt = {}
        cur[part] = nxt
    cur = nxt
cur[parts[-1]] = parsed
with open(path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2, sort_keys=True)
    fh.write("\n")
PY
}

soviez_json_log_line() {
  local level="$1"
  local message="$2"
  soviez_require_cmd python3
  SOVIEZ_LOG_LEVEL="$level" SOVIEZ_LOG_MESSAGE="$message" python3 - <<'PY'
import json, os, time
print(json.dumps({
    "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "level": os.environ["SOVIEZ_LOG_LEVEL"],
    "message": os.environ["SOVIEZ_LOG_MESSAGE"],
}, separators=(",", ":")))
PY
}

soviez_json_pretty() {
  local json="$1"
  soviez_require_cmd python3
  printf '%s' "$json" | python3 -m json.tool 2>/dev/null || printf '%s\n' "$json"
}

soviez_json_merge_file() {
  local file="$1"
  local patch_json="$2"
  soviez_require_cmd python3
  SOVIEZ_JSON_FILE="$file" SOVIEZ_JSON_PATCH="$patch_json" python3 - <<'PY'
import json, os
path = os.environ["SOVIEZ_JSON_FILE"]
patch = json.loads(os.environ["SOVIEZ_JSON_PATCH"])
try:
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
except FileNotFoundError:
    data = {}
def merge(a, b):
    for k, v in b.items():
        if isinstance(v, dict) and isinstance(a.get(k), dict):
            merge(a[k], v)
        else:
            a[k] = v
merge(data, patch)
with open(path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2, sort_keys=True)
    fh.write("\n")
PY
}
