# shellcheck shell=bash

soviez_image_usage_report() {
  local before after
  before="$(soviez_image_docker system df --format '{{json .}}' 2>/dev/null | head -1 || echo '{}')"
  # Prefer docker system df -v JSON when available
  local dfjson
  dfjson="$(soviez_image_docker system df 2>/dev/null || true)"
  SOVIEZ_DF="$dfjson" python3 - <<'PY'
import json,os,re
text=os.environ.get("SOVIEZ_DF") or ""
# Parse human lines for Images row
images_size=None
for line in text.splitlines():
  if line.startswith("Images"):
    parts=re.split(r"\s{2,}", line.strip())
    if len(parts)>=4:
      images_size=parts[3]
print(json.dumps({"docker_df_text":text,"images_size_human":images_size},separators=(",",":")))
PY
}

soviez_image_inspect_sizes() {
  local image_id="$1"
  soviez_image_docker inspect "$image_id" --format '{{json .}}' 2>/dev/null | python3 -c '
import json,sys
d=json.load(sys.stdin)
size=d.get("Size") or 0
print(json.dumps({"image_id":d.get("Id"),"logical_size_bytes":size,"shared_size_note":"Docker layer sharing means reclaim may be less than logical size"},separators=(",",":")))
' 2>/dev/null || echo '{"logical_size_bytes":0}'
}
