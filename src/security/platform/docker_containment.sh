# shellcheck shell=bash
# Security Gate S1 — Docker container baseline containment.

soviez_sec_docker_mounts_include_docker_sock() {
  local container="$1"
  python3 - "$container" <<'PY'
import json, subprocess, sys
cid = sys.argv[1]
raw = subprocess.check_output(["docker", "inspect", cid], text=True)
data = json.loads(raw)[0]
mounts = data.get("Mounts") or []
binds = ((data.get("HostConfig") or {}).get("Binds")) or []
for m in mounts:
    src = (m.get("Source") or "") + " " + (m.get("Destination") or "")
    if "docker.sock" in src:
        sys.exit(0)
for b in binds:
    if "docker.sock" in str(b):
        sys.exit(0)
sys.exit(1)
PY
}

soviez_sec_docker_assert_container_baseline() {
  local container="$1"
  local role="${2:-}"
  [[ -n "$container" ]] || { echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: container required" >&2; return 1; }
  case "$role" in
    odoo|postgres) ;;
    *) echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: role must be odoo|postgres" >&2; return 1 ;;
  esac
  if ! docker inspect "$container" >/dev/null 2>&1; then
    echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: cannot inspect ${container}" >&2
    return 1
  fi

  local privileged network_mode
  privileged="$(docker inspect -f '{{.HostConfig.Privileged}}' "$container" 2>/dev/null || echo UNKNOWN)"
  network_mode="$(docker inspect -f '{{.HostConfig.NetworkMode}}' "$container" 2>/dev/null || echo UNKNOWN)"

  if [[ "$privileged" == "UNKNOWN" || "$network_mode" == "UNKNOWN" ]]; then
    echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: docker inspect incomplete for ${container}" >&2
    return 1
  fi
  if [[ "$privileged" == "true" || "$privileged" == "True" ]]; then
    echo "[error] security:SEC_CRIT_PRIVILEGED_CONTAINER: ${role} container Privileged=true" >&2
    return 1
  fi
  if soviez_sec_docker_mounts_include_docker_sock "$container"; then
    echo "[error] security:SEC_CRIT_DOCKER_SOCKET: ${role} mounts /var/run/docker.sock" >&2
    return 1
  fi
  if [[ "$network_mode" == "host" ]]; then
    echo "[error] security:SEC_CRIT_HOST_NETWORK: ${role} NetworkMode=host" >&2
    return 1
  fi

  local links
  links="$(docker inspect -f '{{json .HostConfig.Links}}' "$container" 2>/dev/null || echo UNKNOWN)"
  if [[ "$links" == "UNKNOWN" ]]; then
    echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: Links inspect failed" >&2
    return 1
  fi
  if [[ "$links" != "null" && "$links" != "[]" && -n "$links" ]]; then
    echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: legacy Links present on ${role}: ${links}" >&2
    return 1
  fi

  # User-defined network: not only default bridge for production.
  # Allow bridge name matching soviez* or SOVIEZ_SEC_DOCKER_NETWORK.
  local mode="${SOVIEZ_SEC_MODE:-}"
  local expected_net="${SOVIEZ_SEC_DOCKER_NETWORK:-}"
  local nets
  nets="$(docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$container" 2>/dev/null || echo "")"
  if [[ -z "$(printf '%s' "$nets" | tr -d '[:space:]')" ]]; then
    # NetworkMode may itself be a custom network name
    if [[ "$network_mode" == "default" || "$network_mode" == "bridge" ]]; then
      if [[ "$mode" == "production" ]]; then
        echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: ${role} on default bridge in production" >&2
        return 1
      fi
    fi
  else
    local ok=0 n
    for n in $nets; do
      if [[ -n "$expected_net" && "$n" == "$expected_net" ]]; then
        ok=1
        break
      fi
      case "$n" in
        soviez*|SOVIEZ*) ok=1; break ;;
      esac
      if [[ "$n" != "bridge" && "$n" != "host" && "$n" != "none" ]]; then
        # Any non-default user-defined network is acceptable.
        ok=1
        break
      fi
    done
    if [[ "$ok" -ne 1 ]]; then
      if [[ "$mode" == "production" ]]; then
        echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: ${role} lacks user-defined/soviez network (nets=${nets})" >&2
        return 1
      fi
    fi
  fi
  return 0
}
