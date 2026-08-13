# shellcheck shell=bash
# Single observation sample of destination sustained health fields.

soviez_migration_p22_observe_once() {
  local cutover_id="${1:-}"
  local http=ok tls=ok db=ok filestore=ok workers=ok cron=ok mail=ok webhook=ok payment=ok
  local queue=ok errors=0 latency_ms=50 backups=ok growth=ok lg=ok dns=ok stages=ok
  local source_writes=0 source_requests=0 duplicates=0 incidents=0

  # Injection hooks for tests (SOVIEZ_MIG_P22_INJECT_*).
  [[ "${SOVIEZ_MIG_P22_INJECT_HTTP_FAIL:-0}" == "1" ]] && http=fail
  [[ "${SOVIEZ_MIG_P22_INJECT_TLS_FAIL:-0}" == "1" ]] && tls=fail
  [[ "${SOVIEZ_MIG_P22_INJECT_DB_FAIL:-0}" == "1" ]] && db=fail
  [[ "${SOVIEZ_MIG_P22_INJECT_FILESTORE_FAIL:-0}" == "1" ]] && filestore=fail
  [[ "${SOVIEZ_MIG_P22_INJECT_WORKERS_FAIL:-0}" == "1" ]] && workers=fail
  [[ "${SOVIEZ_MIG_P22_INJECT_CRON_FAIL:-0}" == "1" ]] && cron=fail
  [[ "${SOVIEZ_MIG_P22_INJECT_MAIL_FAIL:-0}" == "1" ]] && mail=fail
  [[ "${SOVIEZ_MIG_P22_INJECT_WEBHOOK_FAIL:-0}" == "1" ]] && webhook=fail
  [[ "${SOVIEZ_MIG_P22_INJECT_PAYMENT_FAIL:-0}" == "1" ]] && payment=fail
  [[ "${SOVIEZ_MIG_P22_INJECT_QUEUE_FAIL:-0}" == "1" ]] && queue=fail
  [[ "${SOVIEZ_MIG_P22_INJECT_BACKUPS_FAIL:-0}" == "1" ]] && backups=fail
  [[ "${SOVIEZ_MIG_P22_INJECT_LG_FAIL:-0}" == "1" ]] && lg=fail
  [[ "${SOVIEZ_MIG_P22_INJECT_DNS_FAIL:-0}" == "1" ]] && dns=fail
  [[ "${SOVIEZ_MIG_P22_INJECT_STAGES_FAIL:-0}" == "1" ]] && stages=fail
  [[ "${SOVIEZ_MIG_P22_INJECT_ERRORS:-0}" != "0" ]] && errors="${SOVIEZ_MIG_P22_INJECT_ERRORS}"
  [[ -n "${SOVIEZ_MIG_P22_INJECT_LATENCY_MS:-}" ]] && latency_ms="${SOVIEZ_MIG_P22_INJECT_LATENCY_MS}"
  [[ "${SOVIEZ_MIG_P22_INJECT_SOURCE_WRITES:-0}" != "0" ]] && source_writes="${SOVIEZ_MIG_P22_INJECT_SOURCE_WRITES}"
  [[ "${SOVIEZ_MIG_P22_INJECT_SOURCE_REQUESTS:-0}" != "0" ]] && source_requests="${SOVIEZ_MIG_P22_INJECT_SOURCE_REQUESTS}"
  [[ "${SOVIEZ_MIG_P22_INJECT_DUPLICATES:-0}" != "0" ]] && duplicates="${SOVIEZ_MIG_P22_INJECT_DUPLICATES}"
  [[ "${SOVIEZ_MIG_P22_INJECT_INCIDENT:-0}" == "1" ]] && incidents=1
  [[ "${SOVIEZ_MIG_P22_INJECT_GROWTH_FAIL:-0}" == "1" ]] && growth=fail

  SOVIEZ_CID="$cutover_id" SOVIEZ_HTTP="$http" SOVIEZ_TLS="$tls" SOVIEZ_DB="$db" \
  SOVIEZ_FS="$filestore" SOVIEZ_WK="$workers" SOVIEZ_CR="$cron" SOVIEZ_ML="$mail" \
  SOVIEZ_WH="$webhook" SOVIEZ_PAY="$payment" SOVIEZ_Q="$queue" SOVIEZ_ERR="$errors" \
  SOVIEZ_LAT="$latency_ms" SOVIEZ_BK="$backups" SOVIEZ_GR="$growth" SOVIEZ_LG="$lg" \
  SOVIEZ_DNS="$dns" SOVIEZ_STG="$stages" SOVIEZ_SW="$source_writes" SOVIEZ_SR="$source_requests" \
  SOVIEZ_DUP="$duplicates" SOVIEZ_INC="$incidents" \
  SOVIEZ_TS="$(soviez_migration_p22_now_iso)" python3 - <<'PY'
import json, os
print(json.dumps({
  "cutover_id": os.environ["SOVIEZ_CID"],
  "observed_at": os.environ["SOVIEZ_TS"],
  "http": os.environ["SOVIEZ_HTTP"],
  "tls": os.environ["SOVIEZ_TLS"],
  "db": os.environ["SOVIEZ_DB"],
  "filestore": os.environ["SOVIEZ_FS"],
  "workers": os.environ["SOVIEZ_WK"],
  "cron": os.environ["SOVIEZ_CR"],
  "mail": os.environ["SOVIEZ_ML"],
  "webhook": os.environ["SOVIEZ_WH"],
  "payment": os.environ["SOVIEZ_PAY"],
  "queue": os.environ["SOVIEZ_Q"],
  "errors": int(os.environ["SOVIEZ_ERR"]),
  "latency_ms": int(os.environ["SOVIEZ_LAT"]),
  "backups": os.environ["SOVIEZ_BK"],
  "growth": os.environ["SOVIEZ_GR"],
  "license_guard": os.environ["SOVIEZ_LG"],
  "dns": os.environ["SOVIEZ_DNS"],
  "stages": os.environ["SOVIEZ_STG"],
  "source_writes": int(os.environ["SOVIEZ_SW"]),
  "source_requests": int(os.environ["SOVIEZ_SR"]),
  "duplicates": int(os.environ["SOVIEZ_DUP"]),
  "incidents": int(os.environ["SOVIEZ_INC"]),
}, separators=(",", ":")))
PY
}
