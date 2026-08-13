# shellcheck shell=bash
# Security Gate S1 — Odoo production conf defaults.

soviez_sec_odoo_conf_get_option() {
  local conf_path="$1" key="$2"
  [[ -f "$conf_path" ]] || return 1
  local line k v
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*[#\;] ]] && continue
    line="${line%%#*}"
    line="${line%%;*}"
    [[ "$line" == *"="* ]] || continue
    k="${line%%=*}"
    v="${line#*=}"
    k="$(printf '%s' "$k" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    v="$(printf '%s' "$v" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    if [[ "$k" == "$key" ]]; then
      printf '%s\n' "$v"
      return 0
    fi
  done <"$conf_path"
  return 1
}

soviez_sec__odoo_conf_set_option() {
  local conf_path="$1" key="$2" value="$3"
  local tmp parent
  parent="$(dirname "$conf_path")"
  mkdir -p "$parent"
  if [[ ! -f "$conf_path" ]]; then
    printf '[options]\n%s = %s\n' "$key" "$value" >"$conf_path"
    chmod 600 "$conf_path" 2>/dev/null || true
    return 0
  fi
  tmp="$(mktemp "${TMPDIR:-/tmp}/soviez-odoo-conf.XXXXXX")"
  local line k v found=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^[[:space:]]*[#\;] ]] || [[ "$line" != *"="* ]]; then
      printf '%s\n' "$line"
      continue
    fi
    local stripped="${line%%#*}"
    stripped="${stripped%%;*}"
    k="${stripped%%=*}"
    k="$(printf '%s' "$k" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    if [[ "$k" == "$key" ]]; then
      printf '%s = %s\n' "$key" "$value"
      found=1
    else
      printf '%s\n' "$line"
    fi
  done <"$conf_path" >"$tmp"
  if [[ "$found" -eq 0 ]]; then
    printf '%s = %s\n' "$key" "$value" >>"$tmp"
  fi
  mv "$tmp" "$conf_path"
  chmod 600 "$conf_path" 2>/dev/null || true
}

soviez_sec_odoo_conf_ensure_production_defaults() {
  local conf_path="$1"
  local dbfilter="${2:-}"
  [[ -n "$conf_path" ]] || { echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: conf_path required" >&2; return 1; }
  soviez_sec__odoo_conf_set_option "$conf_path" "proxy_mode" "True"
  soviez_sec__odoo_conf_set_option "$conf_path" "list_db" "False"
  if [[ -n "$dbfilter" ]]; then
    soviez_sec__odoo_conf_set_option "$conf_path" "dbfilter" "$dbfilter"
  fi
}

soviez_sec_odoo_conf_assert_production_defaults() {
  local conf_path="$1"
  [[ -f "$conf_path" ]] || {
    echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: odoo conf missing: ${conf_path}" >&2
    return 1
  }
  local proxy list_db
  proxy="$(soviez_sec_odoo_conf_get_option "$conf_path" proxy_mode 2>/dev/null || echo "")"
  list_db="$(soviez_sec_odoo_conf_get_option "$conf_path" list_db 2>/dev/null || echo "")"
  local bad=0
  case "$(printf '%s' "$proxy" | tr '[:upper:]' '[:lower:]')" in
    true|1|yes) ;;
    *)
      echo "[error] security:SEC_CRIT_PROXY_MODE_DISABLED: proxy_mode=${proxy:-unset}" >&2
      bad=1
      ;;
  esac
  case "$(printf '%s' "$list_db" | tr '[:upper:]' '[:lower:]')" in
    false|0|no) ;;
    *)
      echo "[error] security:SEC_CRIT_LIST_DB_ENABLED: list_db=${list_db:-unset}" >&2
      bad=1
      ;;
  esac
  [[ "$bad" -eq 0 ]]
}
