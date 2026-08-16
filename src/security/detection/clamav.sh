# shellcheck shell=bash
# ClamAV integration (complementary to YARA + native scanners).

soviez_clamav_available() {
  command -v clamdscan >/dev/null 2>&1 || command -v clamscan >/dev/null 2>&1
}

soviez_clamav_daemon_status() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl is-active clamav-daemon 2>/dev/null || systemctl is-active clamav-daemon.service 2>/dev/null || echo inactive
  else
    pgrep -x clamd >/dev/null 2>&1 && echo active || echo inactive
  fi
}

soviez_clamav_ensure_packages() {
  # Install only when explicitly requested (mutating harden/tune security path).
  if soviez_clamav_available; then
    return 0
  fi
  if [[ "${SOVIEZ_CLAMAV_AUTO_INSTALL:-0}" != "1" ]]; then
    echo "[info] ClamAV not installed (set SOVIEZ_CLAMAV_AUTO_INSTALL=1 to install)" >&2
    return 0
  fi
  if ! command -v apt-get >/dev/null 2>&1; then
    return 1
  fi
  if declare -F soviez_security_apt_wait_locks >/dev/null 2>&1; then
    soviez_security_apt_wait_locks || return 1
  fi
  DEBIAN_FRONTEND=noninteractive apt-get install -y clamav clamav-daemon clamav-freshclam
}

soviez_clamav_scan_paths() {
  local out="${1:-}"
  shift || true
  local paths=("$@")
  if ! soviez_clamav_available; then
    echo '{"status":"N/A","reason":"clamav_missing"}' >"${out:-/dev/stdout}"
    return 0
  fi
  local bin=clamdscan
  command -v clamdscan >/dev/null 2>&1 || bin=clamscan
  local raw
  raw="$(mktemp)"
  local p rc=0
  for p in "${paths[@]}"; do
    [[ -e "$p" ]] || continue
    # Never recursively on-access scan PGDATA via this helper.
    case "$p" in
      */postgresql/*|*/pgdata/*|*/PG_VERSION) continue ;;
    esac
    "$bin" --no-summary "$p" >>"$raw" 2>/dev/null || rc=$?
  done
  python3 - "$raw" "${out:-/dev/stdout}" "$rc" <<'PY'
import json,sys
raw=open(sys.argv[1],encoding="utf-8",errors="replace").read().splitlines()
out=sys.argv[2]; rc=int(sys.argv[3])
findings=[l for l in raw if "FOUND" in l]
status="PASS"
if findings: status="FAIL"
elif rc not in (0,1): status="ERROR"
json.dump({"status":status,"engine":"clamav","findings":findings[:50],"rc":rc}, open(out,"w") if out!="/dev/stdout" else sys.stdout, indent=2)
if out=="/dev/stdout":
  print()
PY
  rm -f "$raw"
}

soviez_clamav_on_access_scope() {
  # Documented/planned on-access roots (not PGDATA).
  cat <<EOF
filestore
uploads
/opt/soviez
/usr/local
EOF
}
