# shellcheck shell=bash
# Security Gate S1 — PostgreSQL host publish isolation.

soviez_sec__pg_ip_is_loopback() {
  local ip="$1"
  case "$ip" in
    127.0.0.1|127.*|::1) return 0 ;;
    *) return 1 ;;
  esac
}

soviez_sec__pg_ip_is_public_bind() {
  local ip="$1"
  # Empty HostIp in Docker PortBindings means all interfaces.
  case "$ip" in
    ''|0.0.0.0|::|\*|\[::\]) return 0 ;;
  esac
  if soviez_sec__pg_ip_is_loopback "$ip"; then
    return 1
  fi
  return 0
}

soviez_sec_pg_inspect_published_ports() {
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

def emit(src, mapping):
    if not mapping:
        return
    for cport, hosts in mapping.items():
        if not str(cport).startswith("5432"):
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

soviez_sec_pg_assert_no_public_publish() {
  local container="$1"
  local lines
  if ! lines="$(soviez_sec_pg_inspect_published_ports "$container" 2>/dev/null)"; then
    echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: pg publish inspect failed" >&2
    return 1
  fi
  # No publish at all → PASS
  if [[ -z "$(printf '%s' "$lines" | tr -d '[:space:]')" ]]; then
    return 0
  fi
  local src cport hip hport
  while IFS=$'\t' read -r src cport hip hport; do
    [[ -n "$src" ]] || continue
    if [[ "$hip" == "(no-host)" ]]; then
      continue
    fi
    if soviez_sec__pg_ip_is_public_bind "${hip:-}"; then
      echo "[error] security:SEC_CRIT_PG_PUBLIC_PORT: 5432 published on ${hip:-0.0.0.0}:${hport:-?} (${src})" >&2
      return 1
    fi
    if ! soviez_sec__pg_ip_is_loopback "${hip}"; then
      echo "[error] security:SEC_CRIT_PG_PUBLIC_PORT: 5432 non-loopback bind ${hip}:${hport} (${src})" >&2
      return 1
    fi
  done <<<"$lines"
  return 0
}
