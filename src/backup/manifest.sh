# shellcheck shell=bash

soviez_backup_manifest_key_path() {
  soviez_backup_paths_init
  printf '%s/manifest.key\n' "$SOVIEZ_BACKUP_SECRETS_DIR"
}

soviez_backup_manifest_ensure_key() {
  local key
  key="$(soviez_backup_manifest_key_path)"
  if [[ ! -f "$key" ]]; then
    mkdir -p "$(dirname "$key")"
    if command -v openssl >/dev/null 2>&1; then
      openssl rand 32 > "$key"
    else
      python3 -c 'import secrets,sys; sys.stdout.buffer.write(secrets.token_bytes(32))' > "$key"
    fi
    chmod 600 "$key"
  fi
  printf '%s' "$key"
}

soviez_backup_manifest_canonical() {
  # Args: json_without_signature → canonical JSON bytes on stdout
  local json="$1"
  SOVIEZ_J="$json" python3 - <<'PY'
import json, os
obj = json.loads(os.environ["SOVIEZ_J"])
obj.pop("signature", None)
obj.pop("signature_alg", None)
print(json.dumps(obj, separators=(",", ":"), sort_keys=True), end="")
PY
}

soviez_backup_manifest_sign() {
  # Args: canonical_bytes_file OR stdin via env SOVIEZ_CANON
  local canon="${1:-}"
  local key payload
  key="$(soviez_backup_manifest_ensure_key)"
  if [[ -n "$canon" && -f "$canon" ]]; then
    payload="$(cat "$canon")"
  else
    payload="${SOVIEZ_CANON:-}"
  fi
  SOVIEZ_KEY="$key" SOVIEZ_PAYLOAD="$payload" python3 - <<'PY'
import hashlib, hmac, os
key = open(os.environ["SOVIEZ_KEY"], "rb").read()
payload = os.environ["SOVIEZ_PAYLOAD"].encode("utf-8")
print(hmac.new(key, payload, hashlib.sha256).hexdigest())
PY
}

soviez_backup_manifest_write() {
  # Args: dest_file manifest_json_without_signature
  # Forbidden in manifest: passwords, private keys, passphrases, destination secrets.
  local dest="$1" body="$2"
  local canon sig signed
  # Strip secrets if present
  body="$(SOVIEZ_J="$body" python3 - <<'PY'
import json, os
forbid = {"password","pgpassword","passphrase","secret","private_key","access_key",
          "secret_key","encryption_key","aws_secret_access_key","identity_file_contents"}
obj = json.loads(os.environ["SOVIEZ_J"])
def scrub(o):
  if isinstance(o, dict):
    return {k: scrub(v) for k, v in o.items() if k.lower() not in forbid
            and not any(x in k.lower() for x in ("password","passphrase","secret_key"))}
  if isinstance(o, list):
    return [scrub(x) for x in o]
  return o
print(json.dumps(scrub(obj), separators=(",", ":")))
PY
)"
  canon="$(soviez_backup_manifest_canonical "$body")"
  sig="$(SOVIEZ_CANON="$canon" soviez_backup_manifest_sign)"
  signed="$(SOVIEZ_C="$canon" SOVIEZ_S="$sig" python3 - <<'PY'
import json, os
obj = json.loads(os.environ["SOVIEZ_C"])
obj["signature_alg"] = "HMAC-SHA256"
obj["signature"] = os.environ["SOVIEZ_S"]
print(json.dumps(obj, separators=(",", ":"), sort_keys=True))
PY
)"
  mkdir -p "$(dirname "$dest")"
  printf '%s\n' "$signed" > "$dest"
  chmod 600 "$dest"
  printf '%s' "$signed"
}

soviez_backup_manifest_verify() {
  # Args: manifest_file
  local file="$1"
  [[ -f "$file" ]] || soviez_backup_die BACKUP_MANIFEST_FAILED "Missing manifest"
  local body expected actual canon
  body="$(cat "$file")"
  expected="$(soviez_json_get "$body" signature 2>/dev/null || true)"
  [[ -n "$expected" ]] || soviez_backup_die BACKUP_SIGNATURE_INVALID "Manifest missing signature"
  canon="$(soviez_backup_manifest_canonical "$body")"
  actual="$(SOVIEZ_CANON="$canon" soviez_backup_manifest_sign)"
  [[ "$expected" == "$actual" ]] || soviez_backup_die BACKUP_SIGNATURE_INVALID "Manifest signature mismatch"
  return 0
}
