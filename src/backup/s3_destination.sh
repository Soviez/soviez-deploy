# shellcheck shell=bash
# S3-compatible destination: exact-key multipart upload/download/delete.
# Credentials never logged. Fixture short-circuit only when TEST_MODE without REAL flag.

soviez_backup_s3_use_fixture() {
  [[ "${SOVIEZ_TEST_MODE:-0}" == "1" && "${SOVIEZ_BACKUP_S3_REAL:-0}" != "1" ]]
}

soviez_backup_s3_load_creds() {
  # Loads into env SOVIEZ_BACKUP_S3_ACCESS_KEY / SOVIEZ_BACKUP_S3_SECRET_KEY from secret file.
  # Never logs values.
  local profile_id="$1"
  local secret_raw
  secret_raw="$(soviez_backup_destination_read_secret "$profile_id" 2>/dev/null || true)"
  [[ -n "$secret_raw" ]] || return 1
  export SOVIEZ_BACKUP_S3_ACCESS_KEY
  export SOVIEZ_BACKUP_S3_SECRET_KEY
  SOVIEZ_BACKUP_S3_ACCESS_KEY="$(SOVIEZ_S="$secret_raw" python3 -c 'import json,os; print(json.loads(os.environ["SOVIEZ_S"]).get("access_key",""))')"
  SOVIEZ_BACKUP_S3_SECRET_KEY="$(SOVIEZ_S="$secret_raw" python3 -c 'import json,os; print(json.loads(os.environ["SOVIEZ_S"]).get("secret_key",""))')"
  [[ -n "$SOVIEZ_BACKUP_S3_ACCESS_KEY" && -n "$SOVIEZ_BACKUP_S3_SECRET_KEY" ]] || return 1
  return 0
}

soviez_backup_s3_clear_creds() {
  unset SOVIEZ_BACKUP_S3_ACCESS_KEY SOVIEZ_BACKUP_S3_SECRET_KEY 2>/dev/null || true
}

# Pure-stdlib SigV4 path-style S3 client (MinIO/AWS-compatible). No boto3/aws CLI required.
soviez_backup_s3_client() {
  # Args: cmd  (env: endpoint, bucket, access, secret, optional region/part_size/interrupt/state_file)
  local _cmd="$1"
  SOVIEZ_S3_CMD="$_cmd" python3 - <<'PY'
import hashlib, hmac, json, os, sys, time, urllib.error, urllib.parse, urllib.request, xml.etree.ElementTree as ET
from datetime import datetime, timezone

cmd = os.environ["SOVIEZ_S3_CMD"]
endpoint = os.environ["SOVIEZ_S3_ENDPOINT"].rstrip("/")
bucket = os.environ["SOVIEZ_S3_BUCKET"]
access = os.environ["SOVIEZ_S3_ACCESS_KEY"]
secret = os.environ["SOVIEZ_S3_SECRET_KEY"]
region = os.environ.get("SOVIEZ_S3_REGION") or "us-east-1"
part_size = int(os.environ.get("SOVIEZ_S3_PART_SIZE") or str(5 * 1024 * 1024))
if part_size < 5 * 1024 * 1024:
    part_size = 5 * 1024 * 1024
interrupt = os.environ.get("SOVIEZ_BACKUP_S3_INTERRUPT") or ""
state_file = os.environ.get("SOVIEZ_S3_STATE_FILE") or ""
verify_tls = os.environ.get("SOVIEZ_S3_VERIFY_TLS", "1") != "0"
prefix_owner = os.environ.get("SOVIEZ_S3_PREFIX_OWNER") or ""

def die(code, msg):
    print(json.dumps({"ok": False, "code": code, "error": msg}, separators=(",", ":")), file=sys.stderr)
    sys.exit(2)

def utc_amz():
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")

def utc_date():
    return datetime.now(timezone.utc).strftime("%Y%m%d")

def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def sign(key, msg):
    return hmac.new(key, msg.encode("utf-8") if isinstance(msg, str) else msg, hashlib.sha256).digest()

def signing_key(secret, datestamp, region, service="s3"):
    k_date = sign(("AWS4" + secret).encode("utf-8"), datestamp)
    k_region = sign(k_date, region)
    k_service = sign(k_region, service)
    return sign(k_service, "aws4_request")

def parse_endpoint(ep):
    u = urllib.parse.urlparse(ep if "://" in ep else "http://" + ep)
    host = u.netloc or u.path
    scheme = u.scheme or "http"
    return scheme, host

scheme, host = parse_endpoint(endpoint)

def canonical_request(method, canonical_uri, canonical_qs, headers, payload_hash):
    signed_headers = ";".join(sorted(k.lower() for k in headers))
    canonical_headers = "".join(f"{k.lower()}:{headers[k].strip()}\n" for k in sorted(headers, key=str.lower))
    return f"{method}\n{canonical_uri}\n{canonical_qs}\n{canonical_headers}\n{signed_headers}\n{payload_hash}"

def auth_headers(method, path, query, payload, extra_headers=None):
    payload = payload or b""
    payload_hash = sha256_hex(payload)
    amz = utc_amz()
    datestamp = utc_date()
    headers = {
        "Host": host,
        "x-amz-content-sha256": payload_hash,
        "x-amz-date": amz,
    }
    if extra_headers:
        headers.update(extra_headers)
    # path-style URI: /bucket/key...
    canonical_uri = path
    # query must be sorted
    if isinstance(query, dict):
        items = []
        for k in sorted(query):
            items.append(f"{urllib.parse.quote(k, safe='-_.~')}={urllib.parse.quote(str(query[k]), safe='-_.~')}")
        canonical_qs = "&".join(items)
    else:
        canonical_qs = query or ""
    creq = canonical_request(method, canonical_uri, canonical_qs, headers, payload_hash)
    scope = f"{datestamp}/{region}/s3/aws4_request"
    string_to_sign = f"AWS4-HMAC-SHA256\n{amz}\n{scope}\n{sha256_hex(creq.encode('utf-8'))}"
    sig = hmac.new(signing_key(secret, datestamp, region), string_to_sign.encode("utf-8"), hashlib.sha256).hexdigest()
    signed_headers = ";".join(sorted(k.lower() for k in headers))
    headers["Authorization"] = (
        f"AWS4-HMAC-SHA256 Credential={access}/{scope}, SignedHeaders={signed_headers}, Signature={sig}"
    )
    return headers, canonical_qs

def request(method, path, query=None, payload=b"", extra_headers=None, timeout=120):
    headers, qs = auth_headers(method, path, query or {}, payload, extra_headers)
    url = f"{scheme}://{host}{path}"
    if qs:
        url = f"{url}?{qs}"
    req = urllib.request.Request(url, data=payload if method in ("PUT", "POST", "DELETE") else None, method=method)
    for k, v in headers.items():
        req.add_header(k, v)
    ctx = None
    if scheme == "https" and not verify_tls:
        import ssl
        ctx = ssl._create_unverified_context()
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
            body = resp.read()
            return resp.status, dict(resp.headers), body
    except urllib.error.HTTPError as e:
        body = e.read() if hasattr(e, "read") else b""
        return e.code, dict(getattr(e, "headers", {}) or {}), body
    except Exception as e:
        die("BACKUP_DESTINATION_UNREACHABLE", f"S3 request failed: {type(e).__name__}")

def object_path(key):
    return f"/{bucket}/{key.lstrip('/')}"

def save_state(doc):
    if not state_file:
        return
    os.makedirs(os.path.dirname(state_file) or ".", exist_ok=True)
    with open(state_file, "w", encoding="utf-8") as fh:
        json.dump(doc, fh, separators=(",", ":"))

def load_state():
    if state_file and os.path.isfile(state_file):
        with open(state_file, encoding="utf-8") as fh:
            return json.load(fh)
    return {}

def assert_prefix(key):
    if prefix_owner and not key.startswith(prefix_owner.rstrip("/") + "/") and key != prefix_owner.rstrip("/"):
        die("BACKUP_DESTINATION_INVALID", "prefix ownership mismatch")

def ensure_bucket():
    status, _, body = request("HEAD", f"/{bucket}", {})
    if status == 404:
        die("BACKUP_DESTINATION_UNREACHABLE", "bucket missing")
    if status >= 400:
        die("BACKUP_DESTINATION_UNREACHABLE", f"bucket probe HTTP {status}")

def multipart_put(local_path, key):
    assert_prefix(key)
    st = load_state()
    upload_id = st.get("upload_id")
    parts = list(st.get("parts") or [])
    completed = st.get("completed")
    if completed and st.get("key") == key and st.get("etag"):
        print(json.dumps({"ok": True, "code": "S3_PUT_IDEMPOTENT", "key": key, "etag": st["etag"],
                          "upload_id": upload_id}, separators=(",", ":")))
        return
    size = os.path.getsize(local_path)
    if interrupt == "before_first_part" and not upload_id:
        die("BACKUP_TRANSFER_INTERRUPTED", "injected interrupt before_first_part")
    if not upload_id:
        status, hdrs, body = request("POST", object_path(key), {"uploads": ""})
        if status not in (200, 201):
            die("BACKUP_TRANSFER_FAILED", f"create-multipart HTTP {status}: {body[:200]!r}")
        root = ET.fromstring(body)
        ns = ""
        if root.tag.startswith("{"):
            ns = root.tag.split("}")[0] + "}"
        upload_id = root.findtext(f"{ns}UploadId") or ""
        if not upload_id:
            die("BACKUP_TRANSFER_FAILED", "missing UploadId")
        save_state({"key": key, "upload_id": upload_id, "parts": [], "owned": True, "size": size})
        st = load_state()
        parts = []
    uploaded = {int(p["PartNumber"]): p for p in parts}
    with open(local_path, "rb") as fh:
        part_num = 1
        offset = 0
        while offset < size:
            chunk = fh.read(part_size)
            if not chunk:
                break
            if part_num in uploaded:
                offset += len(chunk)
                part_num += 1
                continue
            if interrupt == "middle_part" and part_num == 2:
                die("BACKUP_TRANSFER_INTERRUPTED", "injected interrupt during middle part")
            status, hdrs, body = request(
                "PUT", object_path(key),
                {"partNumber": str(part_num), "uploadId": upload_id},
                chunk,
            )
            if status not in (200, 201):
                die("BACKUP_TRANSFER_FAILED", f"upload part {part_num} HTTP {status}")
            etag = hdrs.get("ETag") or hdrs.get("etag") or ""
            etag = etag.strip('"')
            parts.append({"PartNumber": part_num, "ETag": etag})
            save_state({"key": key, "upload_id": upload_id, "parts": parts, "owned": True, "size": size})
            offset += len(chunk)
            part_num += 1
            # backoff-friendly tiny pause for large counts
            if part_num % 20 == 0:
                time.sleep(0.05)
    if interrupt == "before_complete":
        die("BACKUP_TRANSFER_INTERRUPTED", "injected interrupt after all parts before complete")
    # Complete
    xml_parts = "".join(
        f"<Part><PartNumber>{p['PartNumber']}</PartNumber><ETag>\"{p['ETag']}\"</ETag></Part>"
        for p in sorted(parts, key=lambda x: int(x["PartNumber"]))
    )
    body_xml = f"<CompleteMultipartUpload>{xml_parts}</CompleteMultipartUpload>".encode("utf-8")
    status, hdrs, body = request(
        "POST", object_path(key), {"uploadId": upload_id}, body_xml,
        extra_headers={"Content-Type": "application/xml"},
    )
    if status not in (200, 201):
        die("BACKUP_TRANSFER_FAILED", f"complete-multipart HTTP {status}: {body[:300]!r}")
    # parse etag
    try:
        root = ET.fromstring(body)
        ns = root.tag.split("}")[0] + "}" if root.tag.startswith("{") else ""
        etag = (root.findtext(f"{ns}ETag") or "").strip('"')
    except Exception:
        etag = (hdrs.get("ETag") or "").strip('"')
    save_state({"key": key, "upload_id": upload_id, "parts": parts, "owned": True,
                "completed": True, "etag": etag, "size": size})
    if interrupt == "after_complete_before_local":
        die("BACKUP_TRANSFER_INTERRUPTED", "injected interrupt after complete before local finalization")
    print(json.dumps({"ok": True, "code": "S3_PUT_OK", "key": key, "etag": etag,
                      "upload_id": upload_id, "parts": len(parts)}, separators=(",", ":")))

def abort_owned(key, upload_id):
    assert_prefix(key)
    st = load_state()
    if st.get("upload_id") and st.get("upload_id") != upload_id:
        die("BACKUP_TRANSFER_FAILED", "refusing abort of unrelated upload_id")
    if not st.get("owned", True):
        die("BACKUP_TRANSFER_FAILED", "refusing abort of non-owned multipart")
    status, _, body = request("DELETE", object_path(key), {"uploadId": upload_id})
    if status not in (200, 204):
        die("BACKUP_TRANSFER_FAILED", f"abort multipart HTTP {status}")
    print(json.dumps({"ok": True, "code": "S3_ABORT_OK", "upload_id": upload_id}, separators=(",", ":")))

def head_object(key):
    assert_prefix(key)
    status, hdrs, body = request("HEAD", object_path(key), {})
    if status == 404:
        die("BACKUP_TRANSFER_FAILED", "object missing")
    if status >= 400:
        die("BACKUP_TRANSFER_FAILED", f"head HTTP {status}")
    if interrupt == "during_verify":
        die("BACKUP_TRANSFER_INTERRUPTED", "injected interrupt during remote verification")
    print(json.dumps({
        "ok": True, "code": "S3_HEAD_OK", "key": key,
        "etag": (hdrs.get("ETag") or hdrs.get("etag") or "").strip('"'),
        "content_length": int(hdrs.get("Content-Length") or hdrs.get("content-length") or 0),
        "content_type": hdrs.get("Content-Type") or hdrs.get("content-type") or "",
    }, separators=(",", ":")))

def get_object(key, dest):
    assert_prefix(key)
    if interrupt == "during_download":
        die("BACKUP_TRANSFER_INTERRUPTED", "injected interrupt during download")
    status, hdrs, body = request("GET", object_path(key), {}, timeout=300)
    if status != 200:
        die("BACKUP_TRANSFER_FAILED", f"get HTTP {status}")
    os.makedirs(os.path.dirname(dest) or ".", exist_ok=True)
    with open(dest, "wb") as fh:
        fh.write(body)
    print(json.dumps({
        "ok": True, "code": "S3_GET_OK", "key": key, "bytes": len(body),
        "etag": (hdrs.get("ETag") or "").strip('"'),
        "sha256": sha256_hex(body),
    }, separators=(",", ":")))

def delete_object(key):
    assert_prefix(key)
    if interrupt == "during_delete":
        die("BACKUP_TRANSFER_INTERRUPTED", "injected interrupt during exact-object deletion")
    status, _, body = request("DELETE", object_path(key), {})
    if status not in (200, 204):
        die("BACKUP_TRANSFER_FAILED", f"delete HTTP {status}")
    print(json.dumps({"ok": True, "code": "S3_DELETE_OK", "key": key}, separators=(",", ":")))

def list_exact_prefix(pfx):
    # ListObjectsV2 with prefix; never delete. Caller must use exact keys.
    status, _, body = request("GET", f"/{bucket}", {"list-type": "2", "prefix": pfx})
    if status != 200:
        die("BACKUP_TRANSFER_FAILED", f"list HTTP {status}")
    root = ET.fromstring(body)
    ns = root.tag.split("}")[0] + "}" if root.tag.startswith("{") else ""
    keys = []
    for c in root.findall(f".//{ns}Contents"):
        k = c.findtext(f"{ns}Key")
        if k:
            keys.append(k)
    print(json.dumps({"ok": True, "code": "S3_LIST_OK", "prefix": pfx, "keys": keys}, separators=(",", ":")))

# dispatch
if cmd == "ensure_bucket":
    ensure_bucket()
    print(json.dumps({"ok": True, "code": "S3_BUCKET_OK", "bucket": bucket}, separators=(",", ":")))
elif cmd == "multipart_put":
    multipart_put(os.environ["SOVIEZ_S3_LOCAL"], os.environ["SOVIEZ_S3_KEY"])
elif cmd == "abort":
    abort_owned(os.environ["SOVIEZ_S3_KEY"], os.environ["SOVIEZ_S3_UPLOAD_ID"])
elif cmd == "head":
    head_object(os.environ["SOVIEZ_S3_KEY"])
elif cmd == "get":
    get_object(os.environ["SOVIEZ_S3_KEY"], os.environ["SOVIEZ_S3_LOCAL"])
elif cmd == "delete":
    delete_object(os.environ["SOVIEZ_S3_KEY"])
elif cmd == "list":
    list_exact_prefix(os.environ["SOVIEZ_S3_PREFIX"])
else:
    die("BACKUP_TRANSFER_FAILED", f"unknown s3 cmd {cmd}")
PY
}

soviez_backup_s3_env_from_profile() {
  local profile="$1" profile_id
  profile_id="$(soviez_json_get "$profile" profile_id)"
  export SOVIEZ_S3_ENDPOINT SOVIEZ_S3_BUCKET SOVIEZ_S3_REGION SOVIEZ_S3_PREFIX_OWNER
  SOVIEZ_S3_ENDPOINT="$(soviez_json_get "$profile" endpoint 2>/dev/null || true)"
  SOVIEZ_S3_BUCKET="$(soviez_json_get "$profile" bucket)"
  SOVIEZ_S3_REGION="$(soviez_json_get "$profile" region 2>/dev/null || echo us-east-1)"
  SOVIEZ_S3_PREFIX_OWNER="$(soviez_json_get "$profile" prefix 2>/dev/null || echo backups)"
  soviez_backup_s3_load_creds "$profile_id" || return 1
  export SOVIEZ_S3_ACCESS_KEY="$SOVIEZ_BACKUP_S3_ACCESS_KEY"
  export SOVIEZ_S3_SECRET_KEY="$SOVIEZ_BACKUP_S3_SECRET_KEY"
  return 0
}

soviez_backup_s3_dest_test() {
  local profile="$1"
  local profile_id endpoint bucket
  profile_id="$(soviez_json_get "$profile" profile_id)"
  endpoint="$(soviez_json_get "$profile" endpoint 2>/dev/null || true)"
  bucket="$(soviez_json_get "$profile" bucket)"
  [[ -n "$bucket" ]] || soviez_backup_die BACKUP_DESTINATION_INVALID "s3 bucket required"

  if soviez_backup_s3_use_fixture; then
    soviez_backup_ok BACKUP_DESTINATION_OK "S3 fixture destination ok: $bucket"
    return 0
  fi

  soviez_backup_s3_env_from_profile "$profile" \
    || soviez_backup_die BACKUP_DESTINATION_UNREACHABLE "Missing s3 credentials for $profile_id"
  [[ -n "$endpoint" ]] || soviez_backup_die BACKUP_DESTINATION_INVALID "s3 endpoint required"

  local out
  if ! out="$(soviez_backup_s3_client ensure_bucket 2>&1)"; then
    soviez_backup_s3_clear_creds
    soviez_backup_die BACKUP_DESTINATION_UNREACHABLE "S3 bucket unreachable: $bucket"
  fi
  soviez_backup_s3_clear_creds
  soviez_backup_ok BACKUP_DESTINATION_OK "S3 reachable: $bucket"
}

soviez_backup_s3_object_key() {
  local profile="$1" prod_id="$2" backup_id="$3" filename="$4"
  local prefix
  prefix="$(soviez_json_get "$profile" prefix 2>/dev/null || echo backups)"
  printf '%s/%s/%s/%s' "${prefix%/}" "$prod_id" "$backup_id" "$filename"
}

soviez_backup_s3_dest_put() {
  # Args: profile_json source_dir backup_id production_id
  local profile="$1" src="$2" backup_id="$3" prod_id="$4"
  local profile_id endpoint bucket prefix key
  profile_id="$(soviez_json_get "$profile" profile_id)"
  endpoint="$(soviez_json_get "$profile" endpoint 2>/dev/null || true)"
  bucket="$(soviez_json_get "$profile" bucket)"
  prefix="$(soviez_json_get "$profile" prefix 2>/dev/null || echo backups)"
  key="${prefix%/}/${prod_id}/${backup_id}"

  if soviez_backup_s3_use_fixture; then
    local fixture="${SOVIEZ_BACKUP_ROOT}/s3-fixture/${key}"
    mkdir -p "$fixture"
    cp -a "$src"/. "$fixture/"
    printf 's3://%s/%s\n' "$bucket" "$key"
    return 0
  fi

  soviez_backup_s3_env_from_profile "$profile" \
    || soviez_backup_die BACKUP_TRANSFER_FAILED "Missing s3 credentials"
  [[ -n "$endpoint" ]] || soviez_backup_die BACKUP_DESTINATION_INVALID "s3 endpoint required"

  local f base obj_key state_dir state_file out
  state_dir="${SOVIEZ_BACKUP_OPS_DIR:-${SOVIEZ_ROOT}/backup-ops}/s3-xfer/${prod_id}/${backup_id}"
  mkdir -p "$state_dir"
  chmod 700 "$state_dir"

  shopt -s nullglob
  for f in "$src"/*; do
    [[ -e "$f" ]] || continue
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    obj_key="$(soviez_backup_s3_object_key "$profile" "$prod_id" "$backup_id" "$base")"
    state_file="${state_dir}/${base}.multipart.json"
    export SOVIEZ_S3_LOCAL="$f" SOVIEZ_S3_KEY="$obj_key" SOVIEZ_S3_STATE_FILE="$state_file"
    # Retry/backoff loop
    local attempt=1 max=4 delay=1
    while true; do
      if out="$(soviez_backup_s3_client multipart_put 2>&1)"; then
        break
      fi
      if printf '%s' "$out" | grep -q BACKUP_TRANSFER_INTERRUPTED; then
        soviez_backup_s3_clear_creds
        soviez_backup_die BACKUP_TRANSFER_INTERRUPTED "S3 upload interrupted ($base)"
      fi
      if [[ $attempt -ge $max ]]; then
        soviez_backup_s3_clear_creds
        soviez_backup_die BACKUP_TRANSFER_FAILED "S3 multipart put failed for $base"
      fi
      sleep "$delay"
      delay=$((delay * 2))
      attempt=$((attempt + 1))
    done
    # Head verify exact object
    export SOVIEZ_S3_KEY="$obj_key"
    if ! out="$(soviez_backup_s3_client head 2>&1)"; then
      if printf '%s' "$out" | grep -q BACKUP_TRANSFER_INTERRUPTED; then
        soviez_backup_s3_clear_creds
        soviez_backup_die BACKUP_TRANSFER_INTERRUPTED "S3 verify interrupted"
      fi
      soviez_backup_s3_clear_creds
      soviez_backup_die BACKUP_TRANSFER_FAILED "S3 object verify failed for $base"
    fi
    local remote_len local_len
    remote_len="$(SOVIEZ_O="$out" python3 -c 'import json,os; print(json.loads(os.environ["SOVIEZ_O"]).get("content_length",0))')"
    local_len="$(wc -c < "$f" | tr -d ' ')"
    if [[ "$remote_len" != "$local_len" ]]; then
      soviez_backup_s3_clear_creds
      soviez_backup_die BACKUP_CHECKSUM_MISMATCH "S3 size mismatch for $base"
    fi
  done
  shopt -u nullglob

  # Safe local transfer staging cleanup is caller's concern; we only drop multipart state after success
  rm -f "$state_dir"/*.multipart.json 2>/dev/null || true

  soviez_backup_s3_clear_creds
  printf 's3://%s/%s\n' "$bucket" "$key"
}

soviez_backup_s3_dest_get() {
  # Args: profile_json dest_dir backup_id production_id [filename...]
  local profile="$1" dest="$2" backup_id="$3" prod_id="$4"
  shift 4 || true
  local files=("$@")
  local prefix key obj_key f out
  prefix="$(soviez_json_get "$profile" prefix 2>/dev/null || echo backups)"
  key="${prefix%/}/${prod_id}/${backup_id}"

  if soviez_backup_s3_use_fixture; then
    local fixture="${SOVIEZ_BACKUP_ROOT}/s3-fixture/${key}"
    mkdir -p "$dest"
    cp -a "$fixture"/. "$dest/" 2>/dev/null || true
    printf '%s\n' "$dest"
    return 0
  fi

  soviez_backup_s3_env_from_profile "$profile" \
    || soviez_backup_die BACKUP_TRANSFER_FAILED "Missing s3 credentials"
  mkdir -p "$dest"

  if [[ ${#files[@]} -eq 0 ]]; then
    export SOVIEZ_S3_PREFIX="$key/"
    out="$(soviez_backup_s3_client list 2>&1)" || {
      soviez_backup_s3_clear_creds
      soviez_backup_die BACKUP_TRANSFER_FAILED "S3 list failed"
    }
    while IFS= read -r f; do
      [[ -n "$f" ]] || continue
      files+=("$(basename "$f")")
    done < <(SOVIEZ_O="$out" python3 -c 'import json,os; [print(k) for k in json.loads(os.environ["SOVIEZ_O"]).get("keys",[])]')
  fi

  for f in "${files[@]}"; do
    obj_key="$(soviez_backup_s3_object_key "$profile" "$prod_id" "$backup_id" "$f")"
    export SOVIEZ_S3_KEY="$obj_key" SOVIEZ_S3_LOCAL="$dest/$f"
    if ! out="$(soviez_backup_s3_client get 2>&1)"; then
      soviez_backup_s3_clear_creds
      if printf '%s' "$out" | grep -q BACKUP_TRANSFER_INTERRUPTED; then
        soviez_backup_die BACKUP_TRANSFER_INTERRUPTED "S3 download interrupted"
      fi
      soviez_backup_die BACKUP_TRANSFER_FAILED "S3 get failed for $f"
    fi
  done
  soviez_backup_s3_clear_creds
  printf '%s\n' "$dest"
}

soviez_backup_s3_dest_delete_exact() {
  # Args: profile_json production_id backup_id filename
  # Exact object delete only — never recursive / never prefix wipe.
  local profile="$1" prod_id="$2" backup_id="$3" filename="$4"
  local obj_key out
  [[ -n "$filename" ]] || soviez_backup_die BACKUP_DESTINATION_INVALID "exact object name required"
  case "$filename" in
    */*|*..*|*) ;;
  esac
  if [[ "$filename" == *"/"* || "$filename" == *".."* ]]; then
    soviez_backup_die BACKUP_DESTINATION_INVALID "refuse path-like object name"
  fi

  if soviez_backup_s3_use_fixture; then
    local prefix key
    prefix="$(soviez_json_get "$profile" prefix 2>/dev/null || echo backups)"
    key="${prefix%/}/${prod_id}/${backup_id}"
    rm -f "${SOVIEZ_BACKUP_ROOT}/s3-fixture/${key}/${filename}"
    soviez_backup_ok BACKUP_RETENTION_CLEANUP "S3 fixture exact delete: $filename"
    return 0
  fi

  soviez_backup_s3_env_from_profile "$profile" \
    || soviez_backup_die BACKUP_TRANSFER_FAILED "Missing s3 credentials"
  obj_key="$(soviez_backup_s3_object_key "$profile" "$prod_id" "$backup_id" "$filename")"
  export SOVIEZ_S3_KEY="$obj_key"
  if ! out="$(soviez_backup_s3_client delete 2>&1)"; then
    soviez_backup_s3_clear_creds
    if printf '%s' "$out" | grep -q BACKUP_TRANSFER_INTERRUPTED; then
      soviez_backup_die BACKUP_TRANSFER_INTERRUPTED "S3 exact delete interrupted"
    fi
    soviez_backup_die BACKUP_TRANSFER_FAILED "S3 exact delete failed"
  fi
  soviez_backup_s3_clear_creds
  soviez_backup_ok BACKUP_RETENTION_CLEANUP "S3 exact delete ok: $filename"
}
