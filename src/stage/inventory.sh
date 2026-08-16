# shellcheck shell=bash
# Stage identity, inventory, collision checks (Phase 11).

soviez_stage_sanitize_id() {
  local raw="$1"
  raw="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-' )"
  [[ "$raw" =~ ^[a-z0-9][a-z0-9_-]{1,62}$ ]] || return 1
  printf '%s' "$raw"
}

soviez_stage_normalize_domain() {
  local d="$1"
  d="$(printf '%s' "$d" | tr '[:upper:]' '[:lower:]' | sed -E 's#^https?://##; s#/.*##; s/\.$//')"
  [[ "$d" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$ ]] || return 1
  printf '%s' "$d"
}

soviez_stage_generate_mac() {
  # Locally administered unicast MAC (02:xx:xx:xx:xx:xx), not Production MAC.
  local hex
  hex="$(openssl rand -hex 5)"
  printf '02:%s:%s:%s:%s:%s\n' \
    "${hex:0:2}" "${hex:2:2}" "${hex:4:2}" "${hex:6:2}" "${hex:8:2}"
}

soviez_stage_db_name_for() {
  printf 'stage_%s' "$(printf '%s' "$1" | tr '-' '_')"
}

soviez_stage_container_name_for() {
  printf 'soviez-stage-%s' "$1"
}

soviez_stage_network_name_for() {
  # Dedicated network per Stage (isolation decision — see MULTI_STAGE_RUNTIME_MODEL).
  printf 'soviez-net-stage-%s' "$1"
}

soviez_stage_inventory_corrupt_evidence_path() {
  local idx
  idx="$(soviez_stage_inventory_index)"
  printf '%s.corrupt.%s\n' "$idx" "$(date -u +%Y%m%dT%H%M%SZ)"
}

# Load index JSON; on corrupt content: preserve evidence, clean operator error, non-zero exit.
# Never prints Python traceback to the operator.
soviez_stage_inventory_load_index() {
  local idx
  idx="$(soviez_stage_inventory_index)"
  if [[ ! -f "$idx" ]]; then
    printf '{"stages":[]}\n'
    return 0
  fi
  local raw out
  raw="$(cat "$idx")"
  out="$(mktemp)"
  if ! SOVIEZ_IDX="$raw" python3 - "$out" <<'PY' 2>/dev/null
import json, os, sys
out_path = sys.argv[1]
try:
    data = json.loads(os.environ["SOVIEZ_IDX"])
    if not isinstance(data, dict):
        raise ValueError("index root must be object")
    data.setdefault("stages", [])
    if not isinstance(data["stages"], list):
        raise ValueError("stages must be list")
    open(out_path, "w", encoding="utf-8").write(json.dumps(data) + "\n")
except Exception:
    sys.exit(2)
PY
  then
    rm -f "$out"
    local evidence
    evidence="$(soviez_stage_inventory_corrupt_evidence_path)"
    cp -f "$idx" "$evidence" 2>/dev/null || true
    echo "[error] STAGE_INVENTORY_CORRUPT: stage inventory JSON is unreadable" >&2
    echo "[error] evidence preserved: ${evidence}" >&2
    echo "[error] no automatic repair performed; fix or restore inventory manually" >&2
    return 2
  fi
  cat "$out"
  rm -f "$out"
}

soviez_stage_inventory_atomic_write() {
  local path="$1"
  local content="$2"
  local dir tmp
  dir="$(dirname "$path")"
  mkdir -p "$dir"
  chmod 700 "$dir" 2>/dev/null || true
  tmp="$(mktemp "$dir/.tmp.XXXXXX")"
  printf '%s' "$content" > "$tmp"
  chmod 600 "$tmp"
  mv -f "$tmp" "$path"
}

soviez_stage_inventory_list_ids() {
  local idx_json
  if ! idx_json="$(soviez_stage_inventory_load_index)"; then
    return 2
  fi
  SOVIEZ_IDX="$idx_json" python3 - <<'PY'
import json, os, sys
try:
    data=json.loads(os.environ["SOVIEZ_IDX"])
except Exception:
    print("[error] STAGE_INVENTORY_CORRUPT: cannot parse stage inventory", file=sys.stderr)
    sys.exit(2)
for s in data.get("stages",[]):
    sid=s.get("stage_id") or ""
    if sid:
        print(sid)
PY
}

soviez_stage_inventory_find() {
  local stage_id="$1"
  local file
  file="$(soviez_stage_identity_file "$stage_id")"
  [[ -f "$file" ]] || return 1
  cat "$file"
}

soviez_stage_inventory_assert_unique() {
  local stage_id="$1"
  local domain="$2"
  local db_name="$3"
  local container="$4"
  local mac="$5"
  local id domain_l db c m
  while IFS= read -r id; do
    [[ -z "$id" || "$id" == "$stage_id" ]] && continue
    local ident
    ident="$(soviez_stage_inventory_find "$id" 2>/dev/null || true)"
    [[ -n "$ident" ]] || continue
    domain_l="$(soviez_json_get "$ident" stage_domain 2>/dev/null || true)"
    db="$(soviez_json_get "$ident" stage_db_name 2>/dev/null || true)"
    c="$(soviez_json_get "$ident" stage_container 2>/dev/null || true)"
    m="$(soviez_json_get "$ident" stage_mac 2>/dev/null || true)"
    [[ "$domain_l" == "$domain" ]] && soviez_stage_die STAGE_DOMAIN_CONFLICT "Domain already used: $domain"
    [[ "$db" == "$db_name" ]] && soviez_stage_die STAGE_DB_CONFLICT "DB already used: $db_name"
    [[ "$c" == "$container" ]] && soviez_stage_die STAGE_CONTAINER_CONFLICT "Container already used: $container"
    [[ "$m" == "$mac" ]] && soviez_stage_die STAGE_MAC_CONFLICT "MAC already used: $mac"
  done < <(soviez_stage_inventory_list_ids)

  if [[ -f "$(soviez_stage_identity_file "$stage_id")" ]]; then
    local status
    status="$(soviez_json_get "$(soviez_stage_inventory_find "$stage_id")" lifecycle_status 2>/dev/null || true)"
    if [[ "$status" == "certified" || "$status" == "running" || "$status" == "stopped" ]]; then
      soviez_stage_die STAGE_ID_CONFLICT "Stage already exists: $stage_id"
    fi
  fi
}

soviez_stage_identity_reserve() {
  local stage_id="$1"
  local parent_tenant="$2"
  local license_id="$3"
  local production_fingerprint="$4"
  local source_db_uuid="$5"
  local stage_domain="$6"
  local release_digest="$7"
  local tooling_digest="$8"
  local operation_id="$9"
  local parent_domain="${10:-}"

  stage_id="$(soviez_stage_sanitize_id "$stage_id")" || soviez_stage_die STAGE_ID_CONFLICT "Invalid stage id"
  stage_domain="$(soviez_stage_normalize_domain "$stage_domain")" || soviez_stage_die STAGE_DOMAIN_CONFLICT "Invalid domain"

  local db_name container mac network filestore config secrets
  db_name="$(soviez_stage_db_name_for "$stage_id")"
  container="$(soviez_stage_container_name_for "$stage_id")"
  mac="$(soviez_stage_generate_mac)"
  network="$(soviez_stage_network_name_for "$stage_id")"
  filestore="$(soviez_stage_filestore_path "$stage_id")"
  config="$(soviez_stage_config_path "$stage_id")"
  secrets="$(soviez_stage_secrets_path "$stage_id")"

  soviez_stage_inventory_assert_unique "$stage_id" "$stage_domain" "$db_name" "$container" "$mac"

  mkdir -p "$(soviez_stage_dir "$stage_id")" "$filestore" "$config" "$secrets"
  chmod 700 "$(soviez_stage_dir "$stage_id")" "$secrets"
  chmod 750 "$filestore" "$config"

  local identity
  identity="$(SOVIEZ_SID="$stage_id" SOVIEZ_TENANT="$parent_tenant" SOVIEZ_LIC="$license_id" \
    SOVIEZ_FP="$production_fingerprint" SOVIEZ_UUID="$source_db_uuid" SOVIEZ_DOM="$stage_domain" \
    SOVIEZ_DB="$db_name" SOVIEZ_CTR="$container" SOVIEZ_MAC="$mac" SOVIEZ_NET="$network" \
    SOVIEZ_FS="$filestore" SOVIEZ_CFG="$config" SOVIEZ_SEC="$secrets" \
    SOVIEZ_RD="$release_digest" SOVIEZ_TD="$tooling_digest" SOVIEZ_OP="$operation_id" \
    SOVIEZ_PDOM="$parent_domain" python3 - <<'PY'
import json, os, time
print(json.dumps({
  "stage_id": os.environ["SOVIEZ_SID"],
  "parent_production_tenant_id": os.environ["SOVIEZ_TENANT"],
  "license_id": os.environ["SOVIEZ_LIC"],
  "production_fingerprint": os.environ["SOVIEZ_FP"],
  "source_database_uuid": os.environ["SOVIEZ_UUID"],
  "stage_database_uuid": None,
  "stage_db_name": os.environ["SOVIEZ_DB"],
  "stage_container": os.environ["SOVIEZ_CTR"],
  "stage_mac": os.environ["SOVIEZ_MAC"],
  "stage_network": os.environ["SOVIEZ_NET"],
  "stage_domain": os.environ["SOVIEZ_DOM"],
  "parent_production_domain": os.environ.get("SOVIEZ_PDOM") or None,
  "stage_filestore_path": os.environ["SOVIEZ_FS"],
  "stage_config_path": os.environ["SOVIEZ_CFG"],
  "stage_secrets_path": os.environ["SOVIEZ_SEC"],
  "release_digest": os.environ["SOVIEZ_RD"],
  "tooling_digest": os.environ["SOVIEZ_TD"],
  "operation_id": os.environ["SOVIEZ_OP"],
  "authorization_id": None,
  "origin_certificate_path": None,
  "lifecycle_status": "reserving",
  "health_state": "unknown",
  "retention_created_at": None,
  "retention_expires_at": None,
  "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
}, separators=(",", ":")))
PY
)"
  soviez_stage_inventory_atomic_write "$(soviez_stage_identity_file "$stage_id")" "$identity"

  # Update index
  local index_path new_index
  index_path="$(soviez_stage_inventory_index)"
  new_index="$(SOVIEZ_IDX="$(soviez_stage_inventory_load_index)" SOVIEZ_SID="$stage_id" SOVIEZ_DOM="$stage_domain" python3 - <<'PY'
import json, os
idx=json.loads(os.environ["SOVIEZ_IDX"])
stages=idx.setdefault("stages", [])
stages=[s for s in stages if s.get("stage_id")!=os.environ["SOVIEZ_SID"]]
stages.append({"stage_id": os.environ["SOVIEZ_SID"], "stage_domain": os.environ["SOVIEZ_DOM"]})
idx["stages"]=stages
print(json.dumps(idx, separators=(",", ":")))
PY
)"
  soviez_stage_inventory_atomic_write "$index_path" "$new_index"
  printf '%s' "$identity"
}

soviez_stage_inventory_update_field() {
  local stage_id="$1"
  local patch_json="$2"
  local file
  file="$(soviez_stage_identity_file "$stage_id")"
  [[ -f "$file" ]] || soviez_stage_die RECOVERY_REQUIRED "Missing stage identity: $stage_id"
  local merged
  merged="$(SOVIEZ_CUR="$(cat "$file")" SOVIEZ_PATCH="$patch_json" python3 - <<'PY'
import json, os
cur=json.loads(os.environ["SOVIEZ_CUR"])
cur.update(json.loads(os.environ["SOVIEZ_PATCH"]))
print(json.dumps(cur, separators=(",", ":")))
PY
)"
  soviez_stage_inventory_atomic_write "$file" "$merged"
}
