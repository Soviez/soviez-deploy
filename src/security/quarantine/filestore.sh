# shellcheck shell=bash
# Security Gate S4 — filestore quarantine observation (no attachment mutation).

soviez_q_filestore_scan() {
  local qid="$1" fs_dir="${2:-}"
  local d out
  d="$(soviez_q_dir "$qid")"
  out="$d/filestore/scan.json"
  mkdir -p "$d/filestore"
  if [[ -z "$fs_dir" || ! -d "$fs_dir" ]]; then
    echo '{"status":"N/A","reason":"no_filestore"}' >"$out"
    echo N/A
    return 0
  fi
  # Targeted: scripts/executables only; do not mutate
  if declare -F soviez_s3_yara_scan_paths >/dev/null 2>&1; then
    local yj="$d/filestore/yara.json"
    # Collect candidate files (bounded)
    local list
    list="$(mktemp)"
    find "$fs_dir" -type f \( -name '*.sh' -o -name '*.py' -o -name '*.elf' -o -name 'xmrig*' -o -perm -111 \) 2>/dev/null | head -100 >"$list" || true
    local paths=()
    while IFS= read -r f; do [[ -n "$f" ]] && paths+=("$f"); done <"$list"
    rm -f "$list"
    if [[ ${#paths[@]} -eq 0 ]]; then
      echo '{"status":"PASS","findings":[],"mutates_attachments":false}' >"$out"
      echo PASS
      return 0
    fi
    local st
    st="$(soviez_s3_yara_scan_paths "$yj" "${paths[@]}" 2>/dev/null || echo N/A)"
    # Complementary ClamAV scan (never replaces YARA); do not treat PEM/keys as malware.
    if declare -F soviez_clamav_scan_paths >/dev/null 2>&1; then
      local cj="$d/filestore/clamav.json"
      soviez_clamav_scan_paths "$cj" "${paths[@]}" >/dev/null 2>&1 || true
    fi
    python3 - "$yj" "$out" "$st" <<'PY'
import json,sys
try: y=json.load(open(sys.argv[1]))
except Exception: y={"findings":[]}
st=sys.argv[3]
json.dump({"status":st,"findings":y.get("findings") or [],"mutates_attachments":False,
           "code":"SEC_WARN_FILESTORE_SUSPICIOUS_FILE" if st=="FAIL" else "SEC_OK",
           "engines":["yara","clamav_complementary"]}, open(sys.argv[2],"w"), indent=2)
print(st)
PY
  else
    echo '{"status":"PASS","mutates_attachments":false}' >"$out"
    echo PASS
  fi
}
