# shellcheck shell=bash
# Security Gate S1 — Odoo direct host publish must be loopback-only.

soviez_sec__odoo_ip_is_loopback() {
  local ip="$1"
  case "$ip" in
    127.0.0.1|127.*|::1) return 0 ;;
    *) return 1 ;;
  esac
}

soviez_sec__odoo_ip_is_public_bind() {
  local ip="$1"
  case "$ip" in
    ''|0.0.0.0|::|\*|\[::\]) return 0 ;;
  esac
  soviez_sec__odoo_ip_is_loopback "$ip" && return 1
  return 0
}

soviez_sec_odoo_loopback_publish_spec() {
  local host_port="$1"
  local container_port="${2:-8069}"
  [[ -n "$host_port" ]] || { echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: host_port required" >&2; return 1; }
  printf '127.0.0.1:%s:%s\n' "$host_port" "$container_port"
}

soviez_sec_odoo_inspect_bindings() {
  local container="$1"
  [[ -n "$container" ]] || { echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: container required" >&2; return 1; }
  if ! docker inspect "$container" >/dev/null 2>&1; then
    echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: cannot inspect ${container}" >&2
    return 1
  fi
  python3 - "$container" <<'PY'
import json, subprocess, sys
cid = sys.argv[1]
raw = subprocess.check_output(["docker", "inspect", cid], text=True)
data = json.loads(raw)[0]
bindings = (data.get("HostConfig") or {}).get("PortBindings") or {}
ports = (data.get("NetworkSettings") or {}).get("Ports") or {}
watch = ("8069", "8071", "8072")

def interesting(cport: str) -> bool:
    base = cport.split("/")[0]
    return base in watch

def emit(src, mapping):
    if not mapping:
        return
    for cport, hosts in mapping.items():
        if not interesting(str(cport)):
            continue
        if not hosts:
            print(f"{src}\t{cport}\t(no-host)")
            continue
        for h in hosts:
            hip = h.get("HostIp") if h.get("HostIp") is not None else ""
            hport = h.get("HostPort") or ""
            print(f"{src}\t{cport}\t{hip}\t{hport}")

emit("PortBindings", bindings)
emit("NetworkSettings", ports)
PY
}

soviez_sec_odoo_assert_no_public_direct_ports() {
  local container="$1"
  local lines
  if ! lines="$(soviez_sec_odoo_inspect_bindings "$container" 2>/dev/null)"; then
    echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: odoo binding inspect failed" >&2
    return 1
  fi
  # No publish → PASS
  if [[ -z "$(printf '%s' "$lines" | tr -d '[:space:]')" ]]; then
    return 0
  fi
  local src cport hip hport
  while IFS=$'\t' read -r src cport hip hport; do
    [[ -n "$src" ]] || continue
    [[ "$hip" == "(no-host)" ]] && continue
    if soviez_sec__odoo_ip_is_public_bind "${hip:-}"; then
      echo "[error] security:SEC_CRIT_ODOO_PUBLIC_PORT: ${cport} published on ${hip:-0.0.0.0}:${hport:-?} (${src})" >&2
      return 1
    fi
    if ! soviez_sec__odoo_ip_is_loopback "${hip}"; then
      echo "[error] security:SEC_CRIT_ODOO_PUBLIC_PORT: ${cport} non-loopback ${hip}:${hport} (${src})" >&2
      return 1
    fi
  done <<<"$lines"
  return 0
}

soviez_sec_odoo_assert_binding_is_loopback() {
  local host_port="$1"
  [[ -n "$host_port" ]] || { echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: host_port required" >&2; return 1; }

  # Prefer docker inspect of configured odoo container when available.
  local container="${SOVIEZ_SEC_ODOO_CONTAINER:-}"
  if [[ -n "$container" ]] && docker inspect "$container" >/dev/null 2>&1; then
    local lines hip hport cport src
    lines="$(soviez_sec_odoo_inspect_bindings "$container" 2>/dev/null || true)"
    while IFS=$'\t' read -r src cport hip hport; do
      [[ -n "$src" ]] || continue
      [[ "$hport" == "$host_port" ]] || continue
      if soviez_sec__odoo_ip_is_public_bind "${hip:-}" || ! soviez_sec__odoo_ip_is_loopback "${hip:-}"; then
        echo "[error] security:SEC_CRIT_ODOO_PUBLIC_PORT: host port ${host_port} not loopback (${hip:-0.0.0.0})" >&2
        return 1
      fi
    done <<<"$lines"
  fi

  # Host listener check (ss/lsof) — fail if publicly listening.
  local listeners=""
  if command -v ss >/dev/null 2>&1; then
    listeners="$(ss -ltn 2>/dev/null | awk -v p=":"$host_port'$' '$4 ~ p {print $4}')"
  elif command -v netstat >/dev/null 2>&1; then
    listeners="$(netstat -ltn 2>/dev/null | awk -v p=":"$host_port'$' '$4 ~ p {print $4}')"
  fi
  local addr
  while IFS= read -r addr; do
    [[ -n "$addr" ]] || continue
    case "$addr" in
      127.0.0.1:*|127.*:*|\[::1\]:*|::1:*)
        continue
        ;;
      0.0.0.0:*|\[::\]:*|\*:*)
        echo "[error] security:SEC_CRIT_ODOO_PUBLIC_PORT: listener ${addr} is not loopback" >&2
        return 1
        ;;
      *)
        # Non-loopback explicit bind (e.g. public NIC IP)
        if [[ "$addr" != 127.* && "$addr" != ::1* && "$addr" != \[::1\]* ]]; then
          echo "[error] security:SEC_CRIT_ODOO_PUBLIC_PORT: listener ${addr} is not loopback" >&2
          return 1
        fi
        ;;
    esac
  done <<<"$listeners"
  return 0
}
