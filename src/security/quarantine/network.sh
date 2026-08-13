# shellcheck shell=bash
# Security Gate S4 — quarantine network (deny external egress).

soviez_q_network_create() {
  local qid="$1"
  local d name
  d="$(soviez_q_dir "$qid")"
  mkdir -p "$d/network"
  name="soviez-q-${qid:2:12}-${RANDOM}"
  name="${name//[^a-zA-Z0-9_-]/}"
  if docker network inspect "$name" >/dev/null 2>&1; then
    printf '%s\n' "$name" >"$d/network/name"
    printf '%s\n' "$name"
    return 0
  fi
  if ! docker network create --internal --label "soviez.quarantine=$qid" "$name" >/dev/null 2>&1; then
    echo "[error] security:SEC_CRIT_QUARANTINE_EGRESS_OPEN: cannot create internal network" >&2
    return 1
  fi
  printf '%s\n' "$name" >"$d/network/name"
  printf 'internal=1\negress=DENIED\n' >"$d/network/policy.txt"
  # Record docker Internal flag proof
  docker network inspect "$name" --format '{{.Internal}}' >"$d/network/docker_internal.txt" 2>/dev/null || true
  printf '%s\n' "$name"
}

soviez_q_network_name() {
  cat "$(soviez_q_dir "$1")/network/name" 2>/dev/null || true
}

soviez_q_network_prove_egress_blocked() {
  local qid="$1" probe_cid="$2"
  local d name
  d="$(soviez_q_dir "$qid")"
  name="$(soviez_q_network_name "$qid")"
  # Primary: Docker --internal flag must be true (fail-closed if unknown)
  local internal
  internal="$(docker network inspect "$name" --format '{{.Internal}}' 2>/dev/null || echo "")"
  if [[ "$internal" != "true" ]]; then
    echo "[error] security:SEC_CRIT_QUARANTINE_EGRESS_OPEN: network not Internal (got=${internal:-UNKNOWN})" >&2
    return 1
  fi
  # Secondary: best-effort external probe (may be flaky on some hosts; Internal flag is authoritative)
  if docker exec "$probe_cid" wget -q -O- --timeout=2 http://1.1.1.1 >/dev/null 2>&1; then
    echo "[error] security:SEC_CRIT_QUARANTINE_EGRESS_OPEN: external HTTP succeeded despite Internal" >&2
    return 1
  fi
  echo BLOCKED >"$d/network/egress_proof.txt"
  return 0
}

soviez_q_network_cleanup() {
  local name
  name="$(soviez_q_network_name "$1")"
  [[ -n "$name" ]] || return 0
  docker network rm "$name" >/dev/null 2>&1 || true
}
