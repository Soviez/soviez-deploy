# shellcheck shell=bash

soviez_image_docker() {
  if [[ -n "${DOCKER_HOST:-}" ]]; then
    docker "$@"
  elif [[ -S /Users/raafatagha/.colima/default/docker.sock ]]; then
    DOCKER_HOST=unix:///Users/raafatagha/.colima/default/docker.sock docker "$@"
  else
    docker "$@"
  fi
}

soviez_image_docker_available() {
  soviez_image_docker info >/dev/null 2>&1
}

soviez_image_is_soviez_owned() {
  local image_ref="$1" labels managed product
  labels="$(soviez_image_docker inspect "$image_ref" --format '{{json .Config.Labels}}' 2>/dev/null || echo null)"
  [[ "$labels" != "null" && -n "$labels" ]] || return 1
  managed="$(SOVIEZ_L="$labels" python3 -c 'import json,os; d=json.loads(os.environ["SOVIEZ_L"] or "null") or {}; print(d.get("com.soviez.managed",""))')"
  product="$(SOVIEZ_L="$labels" python3 -c 'import json,os; d=json.loads(os.environ["SOVIEZ_L"] or "null") or {}; print(d.get("com.soviez.product",""))')"
  [[ "$managed" == "true" && "$product" == "erp" ]]
}

soviez_image_digest_of() {
  local image_ref="$1"
  soviez_image_docker inspect "$image_ref" --format '{{.Id}}' 2>/dev/null | sed 's/^sha256://;s/^/sha256:/'
}

soviez_image_list_soviez_erp() {
  # List image IDs that carry Soviez ERP ownership labels
  local id labels
  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    if soviez_image_is_soviez_owned "$id"; then
      labels="$(soviez_image_docker inspect "$id" --format '{{json .Config.Labels}}')"
      SOVIEZ_ID="$id" SOVIEZ_L="$labels" python3 - <<'PY'
import json,os
labels=json.loads(os.environ["SOVIEZ_L"] or "{}")
print(json.dumps({
  "image_id":os.environ["SOVIEZ_ID"],
  "digest":os.environ["SOVIEZ_ID"] if os.environ["SOVIEZ_ID"].startswith("sha256:") else "sha256:"+os.environ["SOVIEZ_ID"].replace("sha256:",""),
  "release_id":labels.get("com.soviez.release-id"),
  "label_digest":labels.get("com.soviez.image-digest"),
  "version":labels.get("org.opencontainers.image.version"),
  "revision":labels.get("org.opencontainers.image.revision"),
  "labels":labels,
},separators=(",",":")))
PY
    fi
  done < <(soviez_image_docker images -q --no-trunc 2>/dev/null | sort -u)
}
