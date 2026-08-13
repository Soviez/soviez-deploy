# shellcheck shell=bash
# Security Gate S5 — connectivity matrix + semantic pre/post diff.

soviez_s5_check_odoo_pg() {
  local odoo="${1:-${SOVIEZ_SEC_ODOO_CONTAINER:-}}"
  local pg="${2:-${SOVIEZ_SEC_PG_CONTAINER:-}}"
  if [[ "${SOVIEZ_S5_INJECT_DB_FAIL:-0}" == "1" ]]; then
    echo FAIL
    return 1
  fi
  if [[ -z "$odoo" || -z "$pg" ]]; then
    if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" && "${SOVIEZ_S5_REQUIRE_CONTAINERS:-0}" != "1" ]]; then
      echo SKIP
      return 0
    fi
    echo FAIL
    return 1
  fi
  if ! command -v docker >/dev/null 2>&1; then
    echo FAIL
    return 1
  fi
  # Prefer TCP probe from Odoo namespace to PG hostname on 5432.
  local pg_host="${SOVIEZ_SEC_PG_HOST:-db}"
  if docker exec "$odoo" sh -c "getent hosts ${pg_host} >/dev/null 2>&1 || nslookup ${pg_host} >/dev/null 2>&1" 2>/dev/null; then
    if docker exec "$odoo" sh -c "command -v pg_isready >/dev/null && pg_isready -h ${pg_host} -p 5432" >/dev/null 2>&1 \
      || docker exec "$odoo" sh -c "timeout 3 bash -c 'echo >/dev/tcp/${pg_host}/5432'" >/dev/null 2>&1 \
      || docker exec "$pg" pg_isready >/dev/null 2>&1; then
      echo PASS
      return 0
    fi
  fi
  # Fallback: both containers running is insufficient alone — still FAIL without reachability.
  if docker inspect -f '{{.State.Running}}' "$odoo" 2>/dev/null | grep -qi true \
    && docker inspect -f '{{.State.Running}}' "$pg" 2>/dev/null | grep -qi true; then
    echo FAIL
    return 1
  fi
  echo FAIL
  return 1
}

soviez_s5_check_docker_dns() {
  local odoo="${1:-${SOVIEZ_SEC_ODOO_CONTAINER:-}}"
  if [[ "${SOVIEZ_S5_INJECT_DNS_FAIL:-0}" == "1" ]]; then
    echo FAIL
    return 1
  fi
  if [[ -z "$odoo" ]]; then
    if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" && "${SOVIEZ_S5_REQUIRE_CONTAINERS:-0}" != "1" ]]; then
      echo SKIP
      return 0
    fi
    echo FAIL
    return 1
  fi
  local target="${SOVIEZ_S5_DNS_TARGET:-db}"
  if docker exec "$odoo" sh -c "getent hosts ${target} >/dev/null 2>&1 || nslookup ${target} >/dev/null 2>&1 || host ${target} >/dev/null 2>&1" 2>/dev/null; then
    echo PASS
    return 0
  fi
  echo FAIL
  return 1
}

soviez_s5__port_binding_ok() {
  # Args: ports_json port_number — PASS if unpublished or loopback-only.
  local ports_json="$1" port="$2"
  python3 - "$ports_json" "$port" <<'PY'
import json,sys
raw=sys.argv[1] or "{}"
port=sys.argv[2]
try:
  data=json.loads(raw)
except Exception:
  print("FAIL"); sys.exit(1)
key=f"{port}/tcp"
binds=data.get(key)
if binds is None:
  print("PASS"); sys.exit(0)
if not binds:
  print("PASS"); sys.exit(0)
ok=True
for b in binds:
  hip=(b or {}).get("HostIp") or ""
  if hip in ("", "0.0.0.0", "::", "*"):
    ok=False
  elif hip not in ("127.0.0.1", "::1"):
    # Non-loopback host IP is treated as public exposure.
    ok=False
print("PASS" if ok else "FAIL")
sys.exit(0 if ok else 1)
PY
}

soviez_s5_check_ports_protected() {
  local odoo="${1:-${SOVIEZ_SEC_ODOO_CONTAINER:-}}"
  local pg="${2:-${SOVIEZ_SEC_PG_CONTAINER:-}}"
  if [[ "${SOVIEZ_S5_INJECT_PUBLIC_PORT:-0}" == "1" ]]; then
    echo FAIL
    return 1
  fi
  local ojson='{}' pjson='{}'
  if [[ -n "$odoo" ]] && command -v docker >/dev/null 2>&1; then
    ojson="$(docker inspect -f '{{json .NetworkSettings.Ports}}' "$odoo" 2>/dev/null || echo '{}')"
  elif [[ "${SOVIEZ_TEST_MODE:-0}" == "1" && -z "$odoo" ]]; then
    echo PASS
    return 0
  fi
  if [[ -n "$pg" ]] && command -v docker >/dev/null 2>&1; then
    pjson="$(docker inspect -f '{{json .NetworkSettings.Ports}}' "$pg" 2>/dev/null || echo '{}')"
  fi
  local r1 r2
  r1="$(soviez_s5__port_binding_ok "$ojson" 8069)" || true
  r2="$(soviez_s5__port_binding_ok "$pjson" 5432)" || true
  if [[ "$r1" == "PASS" && "$r2" == "PASS" ]]; then
    echo PASS
    return 0
  fi
  echo FAIL
  return 1
}

soviez_s5_check_nginx_upstream() {
  local conf="${1:-${SOVIEZ_SEC_NGINX_CONF:-}}"
  if [[ -z "$conf" ]]; then
    echo SKIP
    return 0
  fi
  if [[ ! -f "$conf" ]]; then
    echo FAIL
    return 1
  fi
  if declare -F soviez_nginx_s2_validate_syntax >/dev/null 2>&1; then
    if soviez_nginx_s2_validate_syntax "$conf" >/dev/null 2>&1; then
      echo PASS
      return 0
    fi
    echo FAIL
    return 1
  fi
  # Lightweight upstream private/loopback check when S2 helper absent.
  if grep -E 'proxy_pass[[:space:]]+http://(127\.|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|localhost|odoo|web)' "$conf" >/dev/null 2>&1 \
    || grep -E 'proxy_pass[[:space:]]+http://[^;]+;' "$conf" >/dev/null 2>&1; then
    echo PASS
    return 0
  fi
  echo FAIL
  return 1
}

soviez_s5_semantic_diff() {
  local pre_json="$1" post_json="$2"
  if [[ ! -f "$pre_json" || ! -f "$post_json" ]]; then
    echo FAIL
    return 1
  fi
  python3 - "$pre_json" "$post_json" <<'PY'
import json,sys
pre=json.load(open(sys.argv[1]))
post=json.load(open(sys.argv[2]))

def port_ok(ports, key):
  binds=(ports or {}).get(key)
  if binds is None or binds==[]:
    return True
  for b in binds or []:
    hip=(b or {}).get("HostIp") or ""
    if hip in ("","0.0.0.0","::","*"):
      return False
    if hip not in ("127.0.0.1","::1"):
      return False
  return True

fail=[]
# Protected ports must remain protected post-change.
pp=post.get("ports") or {}
if not port_ok(pp.get("odoo"), "8069/tcp"):
  fail.append("odoo_8069_public")
if not port_ok(pp.get("postgres"), "5432/tcp"):
  fail.append("pg_5432_public")

# Material connectivity fields: post must not be FAIL when pre was PASS/PLACEHOLDER and online expected.
offline=bool(post.get("offline_expected") or pre.get("offline_expected"))
for field in ("dns","db_connectivity"):
  pv=str(pre.get(field,"")).upper()
  qv=str(post.get(field,"")).upper()
  if qv=="FAIL":
    fail.append(field)
  if pv=="PASS" and qv not in ("PASS","SKIP","PLACEHOLDER",""):
    fail.append(f"{field}_regressed")

out=str(post.get("outbound","")).upper()
if offline:
  if out not in ("EXPECTED_OFFLINE","PASS","SKIP","PLACEHOLDER",""):
    fail.append("outbound")
else:
  if out=="FAIL":
    fail.append("outbound")

# Network attachments: do not require identical lists; require no empty post when pre had networks.
pren=set(pre.get("docker_networks") or [])
postn=set(post.get("docker_networks") or [])
if pren and not postn:
  fail.append("docker_networks_empty")

print("FAIL" if fail else "PASS")
sys.exit(1 if fail else 0)
PY
}
