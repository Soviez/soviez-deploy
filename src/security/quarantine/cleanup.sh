# shellcheck shell=bash
# Security Gate S4 — exact-owned temp cleanup (never global prune).

soviez_q_cleanup_temps() {
  local qid="$1"
  local d
  d="$(soviez_q_dir "$qid")"
  # Never delete PRESERVE/INCIDENT
  if [[ -f "$d/PRESERVE" || -f "$d/INCIDENT" || -f "$d/LEGAL_HOLD" ]]; then
    echo "PRESERVE — skip destructive cleanup of $qid"
    # Still remove disposable docker probe names if labeled
    return 0
  fi
  rm -rf "$d/extract"/* 2>/dev/null || true
  local mail
  mail="$(cat "$d/network/mail_sink.txt" 2>/dev/null || true)"
  [[ -n "$mail" ]] && docker rm -f "$mail" >/dev/null 2>&1 || true
  # Do not remove evidence/scans/meta
  return 0
}
