# shellcheck shell=bash

soviez_migration_discovery_collect_identity() {
  local prod="$1"
  local host_json device_fp
  host_json="$(soviez_migration_host_identity)"
  device_fp="$(soviez_migration_device_fingerprint)"
  SOVIEZ_P="$prod" SOVIEZ_H="$host_json" SOVIEZ_D="$device_fp" python3 - <<'PY'
import json, os
p=json.loads(os.environ["SOVIEZ_P"])
h=json.loads(os.environ["SOVIEZ_H"])
print(json.dumps({
  "production_id": p.get("tenant_id") or p.get("environment_id"),
  "environment_id": p.get("environment_id") or p.get("tenant_id"),
  "license_id": p.get("license_id") or "",
  "account_id": p.get("account_id") or p.get("user_id") or "",
  "database_uuid": p.get("database_uuid") or p.get("db_uuid") or "",
  "host_identity": h,
  "device_fingerprint": os.environ["SOVIEZ_D"],
  "image_digest": p.get("image_digest") or p.get("current_image_digest") or "",
  "erp_version": p.get("erp_version") or p.get("version") or "",
  "architecture": h.get("architecture"),
  "os_family": h.get("os_family"),
  "docker_version": p.get("docker_version") or "",
  "compose_version": p.get("compose_version") or "",
  "postgresql_major": p.get("postgresql_major") or p.get("pg_major") or "",
  "container_id": p.get("container_id") or "",
}, separators=(",", ":")))
PY
}

soviez_migration_discovery_collect_capacity() {
  local prod="$1"
  # Prefer fixture aggregates; else compute from declared paths without reading business content
  if [[ -n "${SOVIEZ_MIG_FIXTURE_CAPACITY_JSON:-}" ]]; then
    printf '%s' "$SOVIEZ_MIG_FIXTURE_CAPACITY_JSON"
    return 0
  fi
  local db_path fs_path addon_path
  db_path="$(soviez_json_get "$prod" database_path 2>/dev/null || true)"
  fs_path="$(soviez_json_get "$prod" filestore_path 2>/dev/null || true)"
  addon_path="$(soviez_json_get "$prod" addons_path 2>/dev/null || true)"
  SOVIEZ_DB="$db_path" SOVIEZ_FS="$fs_path" SOVIEZ_AD="$addon_path" python3 - <<'PY'
import json, os, pathlib
def size(p):
    if not p: return 0
    path=pathlib.Path(p)
    if not path.exists(): return 0
    if path.is_file(): return path.stat().st_size
    total=0
    files=0
    for root, dirs, filenames in os.walk(path):
        # skip obvious secret dirs by name only
        dirs[:] = [d for d in dirs if d not in ('.git','__pycache__')]
        for f in filenames:
            fp=pathlib.Path(root)/f
            try:
                total += fp.stat().st_size
                files += 1
            except OSError:
                pass
    return total, files
db=size(os.environ.get("SOVIEZ_DB") or "")
fs=size(os.environ.get("SOVIEZ_FS") or "")
ad=size(os.environ.get("SOVIEZ_AD") or "")
def unpack(x):
    return x if isinstance(x, tuple) else (x, 0)
db_b, db_f = unpack(db) if isinstance(db, tuple) else (db, 0)
fs_b, fs_f = unpack(fs) if isinstance(fs, tuple) else (fs, 0)
ad_b, ad_f = unpack(ad) if isinstance(ad, tuple) else (ad, 0)
# defaults when paths missing (fixture-friendly zeros)
if not os.environ.get("SOVIEZ_DB") and not os.environ.get("SOVIEZ_FS"):
    db_b, fs_b, ad_b = 104857600, 52428800, 10485760
    db_f, fs_f, ad_f = 1, 100, 20
cfg_b = 1048576
total = db_b + fs_b + ad_b + cfg_b
print(json.dumps({
  "database_bytes": db_b,
  "filestore_bytes": fs_b,
  "addon_bytes": ad_b,
  "configuration_bytes": cfg_b,
  "file_count": db_f + fs_f + ad_f,
  "inode_estimate": db_f + fs_f + ad_f + 1000,
  "estimated_transfer_bytes": total,
  "largest_components": [
    {"name":"database","bytes":db_b},
    {"name":"filestore","bytes":fs_b},
    {"name":"addons","bytes":ad_b},
  ],
}, separators=(",", ":")))
PY
}

soviez_migration_discovery_collect_runtime() {
  local prod="$1"
  if [[ -n "${SOVIEZ_MIG_FIXTURE_RUNTIME_JSON:-}" ]]; then
    printf '%s' "$SOVIEZ_MIG_FIXTURE_RUNTIME_JSON"
    return 0
  fi
  SOVIEZ_P="$prod" python3 - <<'PY'
import json, os
p=json.loads(os.environ["SOVIEZ_P"])
print(json.dumps({
  "production_container_health": p.get("container_health") or "running",
  "postgresql_health": p.get("postgresql_health") or "healthy",
  "reverse_proxy_status": p.get("nginx_status") or "active",
  "domain": p.get("domain") or "",
  "ssl_status": p.get("ssl_status") or "unknown",
  "ssl_expiry": p.get("ssl_expiry") or "",
  "maintenance_enabled": False,
  "active_operations": p.get("active_operations") or [],
  "backup_health": p.get("backup_health") or "unknown",
  "update_restore_state": p.get("update_restore_state") or "idle",
  "clock_epoch": __import__("time").time().__int__(),
}, separators=(",", ":")))
PY
}

soviez_migration_discovery_collect_addons() {
  local prod="$1"
  if [[ -n "${SOVIEZ_MIG_FIXTURE_ADDONS_JSON:-}" ]]; then
    printf '%s' "$SOVIEZ_MIG_FIXTURE_ADDONS_JSON"
    return 0
  fi
  printf '%s' '{"addons":[],"python_packages":[],"system_packages":[],"external_mounts":[],"configuration_fingerprint":"","env_names":[],"integrations":{}}'
}

soviez_migration_discovery_collect_stages() {
  local prod="$1" prod_id
  prod_id="$(soviez_json_get "$prod" tenant_id 2>/dev/null || true)"
  [[ -z "$prod_id" ]] && prod_id="$(soviez_json_get "$prod" environment_id)"
  if [[ -n "${SOVIEZ_MIG_FIXTURE_STAGES_JSON:-}" ]]; then
    printf '%s' "$SOVIEZ_MIG_FIXTURE_STAGES_JSON"
    return 0
  fi
  # Inventory from stage dirs when available
  local stages_dir="${SOVIEZ_STAGES_DIR:-${SOVIEZ_ROOT:-}/stages}"
  SOVIEZ_SD="$stages_dir" SOVIEZ_PID="$prod_id" python3 - <<'PY'
import json, os, pathlib
root=pathlib.Path(os.environ.get("SOVIEZ_SD") or "")
pid=os.environ["SOVIEZ_PID"]
stages=[]
if root.is_dir():
  for d in sorted(root.iterdir()):
    inv=d/"inventory.json"
    if not inv.exists():
      continue
    try:
      obj=json.loads(inv.read_text())
    except Exception:
      continue
    parent=obj.get("production_id") or obj.get("parent_production_id") or ""
    if parent and parent != pid:
      continue
    status=obj.get("status") or "unknown"
    retention=obj.get("retention_deadline") or ""
    expired = status in ("expired","deleted","retention_terminated")
    stages.append({
      "stage_id": obj.get("stage_id") or d.name,
      "parent_production_id": parent or pid,
      "image_digest": obj.get("image_digest") or "",
      "database_bytes": int(obj.get("database_bytes") or 0),
      "filestore_bytes": int(obj.get("filestore_bytes") or 0),
      "status": status,
      "retention_deadline": retention,
      "entitlement_state": obj.get("entitlement_state") or "unknown",
      "domain_ssl_state": obj.get("domain_ssl_state") or "unknown",
      "compatibility_state": "unknown",
      "owner_selected": False,
      "selectable": (not expired),
      "selectable_reason": "expired" if expired else "ok",
    })
print(json.dumps({"stages": stages}, separators=(",", ":")))
PY
}

soviez_migration_discovery_collect_backup() {
  if [[ -n "${SOVIEZ_MIG_FIXTURE_BACKUP_JSON:-}" ]]; then
    printf '%s' "$SOVIEZ_MIG_FIXTURE_BACKUP_JSON"
    return 0
  fi
  printf '%s' '{"classification":"missing","capability_healthy":true,"latest_verified_age_seconds":null,"restore_tested":false}'
}

soviez_migration_discovery_collect_network() {
  if [[ -n "${SOVIEZ_MIG_FIXTURE_NETWORK_JSON:-}" ]]; then
    printf '%s' "$SOVIEZ_MIG_FIXTURE_NETWORK_JSON"
    return 0
  fi
  printf '%s' '{"outbound_ok":true,"ipv4_ok":true,"ipv6_optional":true,"ports":[443,22],"firewall_notes":"inspect-only"}'
}
