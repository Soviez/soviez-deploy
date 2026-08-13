# shellcheck shell=bash
# Security Gate S5 — pre/post update baseline capture (local-only evidence).

soviez_s5_evidence_root() {
  if [[ -n "${SOVIEZ_SEC_S5_EVIDENCE_ROOT:-}" ]]; then
    printf '%s\n' "$SOVIEZ_SEC_S5_EVIDENCE_ROOT"
    return 0
  fi
  local base
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    base="${TMPDIR:-/tmp}/soviez-s5-evidence"
  else
    base="${SOVIEZ_ROOT:-/var/lib/soviez}/security/s5"
  fi
  mkdir -p "$base"
  chmod 700 "$base" 2>/dev/null || true
  printf '%s\n' "$base"
}

soviez_s5_op_dir() {
  local op_id="$1"
  local d
  d="$(soviez_s5_evidence_root)/${op_id}"
  mkdir -p "$d"/{baselines,checks,network,reports}
  chmod 700 "$d" 2>/dev/null || true
  printf '%s\n' "$d"
}

soviez_s5__json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/}"
  printf '%s' "$s"
}

soviez_s5__firewall_digest() {
  local blob=""
  if command -v iptables-save >/dev/null 2>&1; then
    blob="$(iptables-save 2>/dev/null || true)"
  elif command -v nft >/dev/null 2>&1; then
    blob="$(nft list ruleset 2>/dev/null || true)"
  elif command -v ufw >/dev/null 2>&1; then
    blob="$(ufw status verbose 2>/dev/null || true)"
  else
    blob="NO_FIREWALL_TOOL"
  fi
  if command -v openssl >/dev/null 2>&1; then
    printf '%s' "$blob" | openssl dgst -sha256 2>/dev/null | awk '{print $NF}'
  else
    printf '%s' "$blob" | cksum | awk '{print $1}'
  fi
}

soviez_s5__docker_networks_json() {
  if ! command -v docker >/dev/null 2>&1; then
    printf '[]'
    return 0
  fi
  # Capture names first so a failed `docker` under pipefail cannot double-print [].
  local names
  names="$(docker network ls --format '{{.Name}}' 2>/dev/null || true)"
  printf '%s\n' "$names" | python3 -c '
import sys,json
print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))
' 2>/dev/null || printf '[]'
}

soviez_s5__published_ports_json() {
  local cid="$1"
  if [[ -z "$cid" ]] || ! command -v docker >/dev/null 2>&1; then
    printf '{}'
    return 0
  fi
  docker inspect -f '{{json .NetworkSettings.Ports}}' "$cid" 2>/dev/null || printf '{}'
}

soviez_s5_baseline_capture() {
  local op_id="${1:-}"
  [[ -n "$op_id" ]] || op_id="s5-$(date -u +%Y%m%dT%H%M%SZ)-$$"
  local d phase="${SOVIEZ_S5_BASELINE_PHASE:-pre}"
  d="$(soviez_s5_op_dir "$op_id")"
  local odoo="${SOVIEZ_SEC_ODOO_CONTAINER:-}"
  local pg="${SOVIEZ_SEC_PG_CONTAINER:-}"
  local fw_digest nets odoo_ports pg_ports
  local dns_status="PLACEHOLDER" outbound_status="PLACEHOLDER" db_status="PLACEHOLDER"
  local offline_expected="false"

  if [[ "${SOVIEZ_S5_OFFLINE:-0}" == "1" || "${SOVIEZ_S5_QUARANTINE:-0}" == "1" ]]; then
    offline_expected="true"
    outbound_status="EXPECTED_OFFLINE"
  fi

  fw_digest="$(soviez_s5__firewall_digest)"
  nets="$(soviez_s5__docker_networks_json)"
  odoo_ports="$(soviez_s5__published_ports_json "$odoo")"
  pg_ports="$(soviez_s5__published_ports_json "$pg")"

  local out="$d/baselines/${phase}.json"
  SOVIEZ_S5_OP="$op_id" SOVIEZ_S5_PHASE="$phase" \
  SOVIEZ_S5_FW="$fw_digest" SOVIEZ_S5_NETS="$nets" \
  SOVIEZ_S5_ODOO="$odoo" SOVIEZ_S5_PG="$pg" \
  SOVIEZ_S5_OPORTS="$odoo_ports" SOVIEZ_S5_PPORTS="$pg_ports" \
  SOVIEZ_S5_DNS="$dns_status" SOVIEZ_S5_OUT="$outbound_status" \
  SOVIEZ_S5_DB="$db_status" SOVIEZ_S5_OFF_EXP="$offline_expected" \
  python3 <<'PY' >"$out"
import json, os, datetime
obj = {
  "gate": "S5",
  "op_id": os.environ["SOVIEZ_S5_OP"],
  "phase": os.environ["SOVIEZ_S5_PHASE"],
  "captured_utc": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
  "odoo_container": os.environ.get("SOVIEZ_S5_ODOO", ""),
  "pg_container": os.environ.get("SOVIEZ_S5_PG", ""),
  "firewall_digest": os.environ.get("SOVIEZ_S5_FW", ""),
  "docker_networks": json.loads(os.environ.get("SOVIEZ_S5_NETS") or "[]"),
  "ports": {
    "odoo": json.loads(os.environ.get("SOVIEZ_S5_OPORTS") or "{}"),
    "postgres": json.loads(os.environ.get("SOVIEZ_S5_PPORTS") or "{}"),
  },
  "dns": os.environ.get("SOVIEZ_S5_DNS", "PLACEHOLDER"),
  "outbound": os.environ.get("SOVIEZ_S5_OUT", "PLACEHOLDER"),
  "db_connectivity": os.environ.get("SOVIEZ_S5_DB", "PLACEHOLDER"),
  "offline_expected": os.environ.get("SOVIEZ_S5_OFF_EXP") == "true",
  "local_only": True,
  "telemetry": False,
}
print(json.dumps(obj, indent=2))
PY
  chmod 600 "$out" 2>/dev/null || true
  printf '%s\n' "$out"
}
