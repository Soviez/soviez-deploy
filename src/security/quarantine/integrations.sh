# shellcheck shell=bash
# Security Gate S4 — webhook/integration/ZATCA outbound containment.

soviez_q_webhook_prove_blocked() {
  local qid="$1" probe_cid="$2"
  if docker exec "$probe_cid" wget -q -O- --timeout=3 http://198.51.100.99/webhook >/dev/null 2>&1; then
    echo "[error] security:SEC_HIGH_UNKNOWN_EXTERNAL_INTEGRATION: webhook egress open" >&2
    return 1
  fi
  echo WEBHOOK_BLOCKED >"$(soviez_q_dir "$qid")/network/webhook_proof.txt"
  return 0
}

soviez_q_zatca_outbound_prove_blocked() {
  local qid="$1" probe_cid="$2"
  if docker exec "$probe_cid" wget -q -O- --timeout=3 https://gw.zatca.gov.sa/ >/dev/null 2>&1; then
    echo "[error] security:SEC_CRIT_QUARANTINE_EGRESS_OPEN: ZATCA egress open" >&2
    return 1
  fi
  echo ZATCA_OUTBOUND_BLOCKED >"$(soviez_q_dir "$qid")/network/zatca_proof.txt"
  return 0
}
