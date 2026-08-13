# shellcheck shell=bash
# Security Gate S4 — mail neutralization.

soviez_q_mail_sink_start() {
  local qid="$1" net="$2"
  local d name
  d="$(soviez_q_dir "$qid")"
  name="soviez-q-mail-${qid:0:12}"
  name="${name//[^a-zA-Z0-9_-]/}"
  if docker inspect "$name" >/dev/null 2>&1; then
    printf '%s\n' "$name"
    return 0
  fi
  docker run -d --name "$name" --network "$net" --network-alias mailsink \
    -l "soviez.quarantine=$qid" busybox:1.36 \
    sh -c 'while true; do nc -l -p 2525 >/tmp/mail.raw 2>/dev/null || sleep 1; done' >/dev/null \
    || { echo "[error] security:SEC_CRIT_MAIL_ACTIVE_IN_QUARANTINE: sink start failed" >&2; return 1; }
  printf '%s\n' "$name" >"$d/network/mail_sink.txt"
  printf '%s\n' "$name"
}

soviez_q_mail_prove_no_external() {
  local qid="$1" probe_cid="$2"
  if docker exec "$probe_cid" sh -c 'echo EHLO | nc -w 2 8.8.8.8 25' >/dev/null 2>&1; then
    echo "[error] security:SEC_CRIT_MAIL_ACTIVE_IN_QUARANTINE: external SMTP reachable" >&2
    return 1
  fi
  echo MAIL_EXTERNAL_BLOCKED >"$(soviez_q_dir "$qid")/network/mail_proof.txt"
  return 0
}
