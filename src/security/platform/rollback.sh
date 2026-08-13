# shellcheck shell=bash
# Security Gate S1 — safe rollback snapshots (never restore dangerous privileges).

soviez_sec_rollback_snapshot_dir() {
  local base="${SOVIEZ_SEC_ROLLBACK_DIR:-${SOVIEZ_SEC_REPORT_DIR:-${TMPDIR:-/tmp}/soviez-sec}/rollback}"
  local stamp
  stamp="$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || date +%s)"
  local dir="${base}/${stamp}"
  mkdir -p "$dir"
  chmod 700 "$dir" 2>/dev/null || true

  local pg="${SOVIEZ_SEC_PG_CONTAINER:-}"
  local odoo="${SOVIEZ_SEC_ODOO_CONTAINER:-}"
  local admin_user="${SOVIEZ_SEC_PG_ADMIN_USER:-${SOVIEZ_PG_ADMIN_USER:-soviez_admin}}"
  local admin_pass="${SOVIEZ_SEC_PG_ADMIN_PASS:-}"
  local app_user="${SOVIEZ_SEC_PG_APP_USER:-${SOVIEZ_PG_APP_USER:-soviez_app}}"
  local conf="${SOVIEZ_SEC_ODOO_CONF:-}"

  if [[ -n "$pg" ]] && declare -F soviez_sec_pg_query_role_attrs >/dev/null 2>&1 && [[ -n "$admin_pass" ]]; then
    local attrs
    attrs="$(soviez_sec_pg_query_role_attrs "$pg" "$admin_user" "$admin_pass" "$app_user" postgres 2>/dev/null || echo "UNKNOWN,UNKNOWN,UNKNOWN,UNKNOWN,UNKNOWN")"
    python3 - "$dir/role_attrs.json" "$app_user" "$attrs" <<'PY'
import json, sys
path, user, attrs = sys.argv[1], sys.argv[2], sys.argv[3]
parts = attrs.split(",")
keys = ["rolsuper","rolcreaterole","rolcreatedb","rolreplication","rolbypassrls"]
obj = {"role": user, "attrs": {}}
for i,k in enumerate(keys):
    obj["attrs"][k] = parts[i] if i < len(parts) else "UNKNOWN"
with open(path, "w", encoding="utf-8") as f:
    json.dump(obj, f, indent=2)
    f.write("\n")
PY
  else
    printf '{"role":"%s","attrs":{"note":"unavailable"}}\n' "$app_user" >"$dir/role_attrs.json"
  fi

  if [[ -n "$pg" ]] && docker inspect "$pg" >/dev/null 2>&1; then
    docker inspect "$pg" --format '{{json .HostConfig.PortBindings}}' >"$dir/pg_port_bindings.json" 2>/dev/null || echo '{}' >"$dir/pg_port_bindings.json"
    docker inspect "$pg" --format '{{json .NetworkSettings.Ports}}' >"$dir/pg_network_ports.json" 2>/dev/null || echo '{}' >"$dir/pg_network_ports.json"
  fi
  if [[ -n "$odoo" ]] && docker inspect "$odoo" >/dev/null 2>&1; then
    docker inspect "$odoo" --format '{{json .HostConfig.PortBindings}}' >"$dir/odoo_port_bindings.json" 2>/dev/null || echo '{}' >"$dir/odoo_port_bindings.json"
    docker inspect "$odoo" --format '{{json .NetworkSettings.Ports}}' >"$dir/odoo_network_ports.json" 2>/dev/null || echo '{}' >"$dir/odoo_network_ports.json"
  fi
  if [[ -n "$conf" && -f "$conf" ]]; then
    cp -a "$conf" "$dir/odoo.conf.copy"
    chmod 600 "$dir/odoo.conf.copy" 2>/dev/null || true
  fi

  printf '%s\n' "$dir" >"$dir/SNAPSHOT_PATH"
  printf '%s\n' "$dir"
}

soviez_sec_rollback_forbidden_privilege_restore() {
  echo "[error] security:SEC_CRIT_PG_SUPERUSER: refusing privilege restore (SUPERUSER/dangerous memberships/weak passwords never restored)" >&2
  return 1
}

soviez_sec_rollback_restore_safe() {
  local snap="${1:-}"
  [[ -n "$snap" && -d "$snap" ]] || {
    echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: snapshot dir required" >&2
    return 1
  }

  # Explicitly refuse any privilege re-escalation path.
  if [[ "${SOVIEZ_SEC_ROLLBACK_ALLOW_PRIVILEGE:-0}" == "1" ]]; then
    soviez_sec_rollback_forbidden_privilege_restore
    return 1
  fi

  local conf="${SOVIEZ_SEC_ODOO_CONF:-}"
  if [[ -n "$conf" && -f "$snap/odoo.conf.copy" ]]; then
    # Restore conf only after scrubbing dangerous weak defaults is NOT done here;
    # restore connectivity-oriented options; never inject SUPERUSER markers (N/A in conf).
    mkdir -p "$(dirname "$conf")"
    cp -a "$snap/odoo.conf.copy" "$conf"
    chmod 600 "$conf" 2>/dev/null || true
    # Re-assert production defaults if helpers present (safe direction).
    if declare -F soviez_sec_odoo_conf_ensure_production_defaults >/dev/null 2>&1; then
      local dbfilter=""
      dbfilter="$(soviez_sec_odoo_conf_get_option "$conf" dbfilter 2>/dev/null || true)"
      soviez_sec_odoo_conf_ensure_production_defaults "$conf" "$dbfilter"
    fi
  fi

  # Port binding / connectivity note: docker port republish requires recreate; record intent only.
  if [[ -f "$snap/odoo_port_bindings.json" ]]; then
    cp -a "$snap/odoo_port_bindings.json" "${SOVIEZ_SEC_REPORT_DIR:-$snap}/restore_odoo_port_bindings.intent.json" 2>/dev/null || true
  fi
  if [[ -f "$snap/pg_port_bindings.json" ]]; then
    # Never restore a public 5432 publish even if snapshot had one.
    if grep -Eq '0\.0\.0\.0|"HostIp": ?""|"HostIp":null' "$snap/pg_port_bindings.json" 2>/dev/null; then
      echo "[warn] security: refusing to restore public PG publish from snapshot" >&2
    else
      cp -a "$snap/pg_port_bindings.json" "${SOVIEZ_SEC_REPORT_DIR:-$snap}/restore_pg_port_bindings.intent.json" 2>/dev/null || true
    fi
  fi

  # NEVER restore SUPERUSER / dangerous memberships / weak passwords from role_attrs.json
  if [[ -f "$snap/role_attrs.json" ]]; then
    if python3 - "$snap/role_attrs.json" <<'PY'
import json,sys
obj=json.load(open(sys.argv[1],encoding="utf-8"))
attrs=(obj.get("attrs") or {})
dangerous=False
for k in ("rolsuper","rolcreaterole","rolreplication","rolbypassrls"):
    v=str(attrs.get(k,"")).lower()
    if v in ("t","true","1","yes"):
        dangerous=True
if dangerous:
    sys.exit(2)
sys.exit(0)
PY
    then
      :
    else
      rc=$?
      if [[ $rc -eq 2 ]]; then
        soviez_sec_rollback_forbidden_privilege_restore
        return 1
      fi
    fi
  fi
  return 0
}
