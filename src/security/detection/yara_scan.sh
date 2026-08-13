# shellcheck shell=bash
# Security Gate S3 — targeted YARA scanning (offline curated rules).

soviez_s3_yara_available() {
  command -v yara >/dev/null 2>&1 || command -v yara3 >/dev/null 2>&1
}

soviez_s3_yara_scan_paths() {
  local out_json="${1:-}"
  shift || true
  local paths=("$@")
  local share rules
  share="$(soviez_s3_detection_share)"
  rules="${share}/yara/soviez_s3.yar"
  [[ -f "$rules" ]] || { echo '{"status":"N/A","reason":"rules_missing"}'; return 0; }

  if ! soviez_s3_yara_available; then
    # Fallback: string scan using rules as patterns via python (no yara binary)
    python3 - "$rules" "$out_json" "${paths[@]}" <<'PY'
import json,sys,re,hashlib,os
rules_path=sys.argv[1]; out=sys.argv[2]; paths=sys.argv[3:]
text=open(rules_path,encoding="utf-8",errors="replace").read()
# crude extract of ascii strings from yar
strings=re.findall(r'=\s*"([^"]+)"', text)
findings=[]
def iter_files(roots, limit=200):
  n=0
  for root in roots:
    if os.path.isfile(root):
      yield root; n+=1
      continue
    if not os.path.isdir(root):
      continue
    for dirpath,_,files in os.walk(root):
      # avoid deep/huge trees
      depth=dirpath[len(root):].count(os.sep)
      if depth>2: continue
      for fn in files:
        yield os.path.join(dirpath,fn)
        n+=1
        if n>=limit: return

findings=[]
for p in iter_files(paths):
  try:
    data=open(p,"rb").read(2_000_000)
  except Exception:
    continue
  s=data.decode("utf-8","replace")
  hit=[st for st in strings if st.lower() in s.lower()]
  if hit:
    findings.append({
      "file":p,
      "sha256":hashlib.sha256(data).hexdigest(),
      "matched_strings":hit[:10],
      "severity":"HIGH",
      "engine":"fallback_string",
    })
status="PASS" if not findings else "FAIL"
json.dump({"status":status,"engine":"fallback_string","findings":findings}, open(out,"w"), indent=2)
print(status)
PY
    return 0
  fi

  local bin=yara
  command -v yara >/dev/null 2>&1 || bin=yara3
  local raw
  raw="$(mktemp)"
  local p
  for p in "${paths[@]}"; do
    [[ -e "$p" ]] || continue
    "$bin" -r "$rules" "$p" >>"$raw" 2>/dev/null || true
  done
  python3 - "$raw" "$out_json" <<'PY'
import json,sys
lines=open(sys.argv[1],encoding="utf-8",errors="replace").read().strip().splitlines()
findings=[{"raw":l,"severity":"HIGH","engine":"yara"} for l in lines if l.strip()]
status="PASS" if not findings else "FAIL"
json.dump({"status":status,"engine":"yara","findings":findings}, open(sys.argv[2],"w"), indent=2)
print(status)
PY
  rm -f "$raw"
}
