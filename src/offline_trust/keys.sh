# shellcheck shell=bash
# Phase 23 — purpose-separated Ed25519 trust roots (public verify; private never in bundles).

soviez_offline_openssl() {
  if declare -F soviez_openssl_bin >/dev/null 2>&1; then
    soviez_openssl_bin
    return 0
  fi
  if [[ -n "${SOVIEZ_OPENSSL:-}" && -x "${SOVIEZ_OPENSSL}" ]]; then
    printf '%s\n' "$SOVIEZ_OPENSSL"
    return 0
  fi
  local c
  for c in /opt/homebrew/bin/openssl /usr/local/opt/openssl@3/bin/openssl /usr/local/bin/openssl; do
    if [[ -x "$c" ]] && "$c" version 2>/dev/null | grep -qi 'OpenSSL'; then
      printf '%s\n' "$c"
      return 0
    fi
  done
  command -v openssl
}

soviez_offline_trust_paths_init() {
  soviez_paths_init 2>/dev/null || true
  SOVIEZ_OFFLINE_TRUST_DIR="${SOVIEZ_OFFLINE_TRUST_DIR:-${SOVIEZ_ROOT:-/tmp/soviez}/offline_trust}"
  # Always nest keys under the active trust dir (do not reuse a stale KEYS_DIR env).
  SOVIEZ_OFFLINE_TRUST_KEYS_DIR="$SOVIEZ_OFFLINE_TRUST_DIR/keys"
  SOVIEZ_OFFLINE_TRUST_STATE="$SOVIEZ_OFFLINE_TRUST_DIR/state.json"
  mkdir -p "$SOVIEZ_OFFLINE_TRUST_KEYS_DIR"
  export SOVIEZ_OFFLINE_TRUST_DIR SOVIEZ_OFFLINE_TRUST_KEYS_DIR SOVIEZ_OFFLINE_TRUST_STATE
}

# Purposes: authorization | bundle_manifest | release | addon | trust_root | revocation | result_receipt
soviez_offline_trust_purpose_ok() {
  case "$1" in
    authorization|bundle_manifest|release|addon|trust_root|revocation|result_receipt) return 0 ;;
    *) return 1 ;;
  esac
}

soviez_offline_trust_ensure_purpose_keypair() {
  local purpose="$1"
  local ossl
  ossl="$(soviez_offline_openssl)"
  soviez_offline_trust_paths_init
  soviez_offline_trust_purpose_ok "$purpose" || return 1
  local priv pub
  priv="$SOVIEZ_OFFLINE_TRUST_KEYS_DIR/${purpose}.key"
  pub="$SOVIEZ_OFFLINE_TRUST_KEYS_DIR/${purpose}.pub"
  if [[ ! -f "$priv" ]]; then
    "$ossl" genpkey -algorithm ED25519 -out "$priv" 2>/dev/null || return 1
    chmod 600 "$priv"
    "$ossl" pkey -in "$priv" -pubout -out "$pub" 2>/dev/null || return 1
    chmod 644 "$pub"
  fi
  [[ -f "$priv" && -f "$pub" ]]
}

soviez_offline_trust_sign_payload() {
  local purpose="$1" payload="$2"
  local priv sig_bin msgf ossl
  ossl="$(soviez_offline_openssl)"
  soviez_offline_trust_ensure_purpose_keypair "$purpose" || return 1
  priv="$SOVIEZ_OFFLINE_TRUST_KEYS_DIR/${purpose}.key"
  sig_bin="$(mktemp "${TMPDIR:-/tmp}/soviez-p23-sig.XXXXXX")"
  msgf="$(mktemp "${TMPDIR:-/tmp}/soviez-p23-msg.XXXXXX")"
  printf '%s' "$payload" > "$msgf"
  # OpenSSL 3.x ED25519 requires -rawin with a seekable input file
  if ! "$ossl" pkeyutl -sign -inkey "$priv" -rawin -in "$msgf" -out "$sig_bin" 2>/dev/null; then
    if ! printf '%s' "$payload" | "$ossl" pkeyutl -sign -inkey "$priv" -in /dev/stdin -out "$sig_bin" 2>/dev/null; then
      rm -f "$sig_bin" "$msgf"
      return 1
    fi
  fi
  "$ossl" base64 -A -in "$sig_bin" | tr '+/' '-_' | tr -d '='
  rm -f "$sig_bin" "$msgf"
}

soviez_offline_trust_verify_payload() {
  local purpose="$1" payload="$2" signature_b64url="$3" pub_override="${4:-}"
  local pub sig_bin msgf ossl
  ossl="$(soviez_offline_openssl)"
  if [[ -n "$pub_override" && -f "$pub_override" ]]; then
    pub="$pub_override"
  else
    soviez_offline_trust_paths_init
    pub="$SOVIEZ_OFFLINE_TRUST_KEYS_DIR/${purpose}.pub"
  fi
  [[ -f "$pub" ]] || return 1
  sig_bin="$(mktemp "${TMPDIR:-/tmp}/soviez-p23-vsig.XXXXXX")"
  msgf="$(mktemp "${TMPDIR:-/tmp}/soviez-p23-vmsg.XXXXXX")"
  printf '%s' "$payload" > "$msgf"
  local pad=$(( (4 - ${#signature_b64url} % 4) % 4 ))
  local padded="$signature_b64url"
  while [[ $pad -gt 0 ]]; do padded="${padded}="; pad=$((pad - 1)); done
  printf '%s' "$padded" | tr '_-' '/+' | "$ossl" base64 -d -A -out "$sig_bin" 2>/dev/null || {
    rm -f "$sig_bin" "$msgf"
    return 1
  }
  if ! "$ossl" pkeyutl -verify -pubin -inkey "$pub" -rawin -in "$msgf" -sigfile "$sig_bin" >/dev/null 2>&1; then
    rm -f "$sig_bin" "$msgf"
    return 1
  fi
  rm -f "$sig_bin" "$msgf"
  return 0
}

soviez_offline_trust_canonical_json_file() {
  local path="$1"
  SOVIEZ_P="$path" python3 - <<'PY'
import json, os
d=json.load(open(os.environ["SOVIEZ_P"]))
for k in ("signature","signature_b64url","signed_at","signer_purpose"):
  d.pop(k, None)
print(json.dumps(d, sort_keys=True, separators=(",", ":")))
PY
}

soviez_offline_trust_sign_json_file() {
  local purpose="$1" path="$2"
  local body sig
  body="$(soviez_offline_trust_canonical_json_file "$path")"
  sig="$(soviez_offline_trust_sign_payload "$purpose" "$body")" || return 1
  SOVIEZ_P="$path" SOVIEZ_B="$body" SOVIEZ_S="$sig" SOVIEZ_PUR="$purpose" python3 - <<'PY'
import json, os, datetime
doc=json.loads(os.environ["SOVIEZ_B"])
doc["signature_b64url"]=os.environ["SOVIEZ_S"]
doc["signer_purpose"]=os.environ["SOVIEZ_PUR"]
doc["signed_at"]=datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
open(os.environ["SOVIEZ_P"],"w").write(json.dumps(doc, separators=(",", ":")))
PY
  printf '%s\n' "$sig" > "${path}.sig"
}

soviez_offline_trust_verify_json_file() {
  local purpose="$1" path="$2" pub_override="${3:-}"
  local body sig
  body="$(soviez_offline_trust_canonical_json_file "$path")"
  sig="$(soviez_json_get "$(cat "$path")" signature_b64url 2>/dev/null || true)"
  if [[ -z "$sig" && -f "${path}.sig" ]]; then
    sig="$(tr -d '[:space:]' < "${path}.sig")"
  fi
  [[ -n "$sig" ]] || return 1
  # Phase 24: reject fixture string signatures in production / certification.
  # Disposable test bypass may accept fixtures unless a certification profile forbids them.
  local reject_fake=1
  if declare -F soviez_security_test_bypass_allowed >/dev/null 2>&1 && soviez_security_test_bypass_allowed; then
    if [[ "${SOVIEZ_PHASE23_CERTIFICATION:-0}" != "1" \
       && "${SOVIEZ_PHASE23_FORBID_FAKE_SIGNATURES:-0}" != "1" \
       && "${SOVIEZ_PHASE24_CERTIFICATION:-0}" != "1" ]]; then
      reject_fake=0
    fi
  fi
  if [[ "$reject_fake" == "1" ]]; then
    if [[ "$sig" == "ok" || "$sig" == "valid" || "$sig" == "fixture" || "$sig" == "tampered" ]]; then
      return 1
    fi
    if declare -F soviez_security_is_fake_signature >/dev/null 2>&1 && soviez_security_is_fake_signature "$sig"; then
      return 1
    fi
  fi
  soviez_offline_trust_verify_payload "$purpose" "$body" "$sig" "$pub_override"
}

soviez_offline_trust_state_init() {
  soviez_offline_trust_paths_init
  if [[ ! -f "$SOVIEZ_OFFLINE_TRUST_STATE" ]]; then
    printf '{"schema":"soviez.offline_trust_state.v1","sequence":0,"last_trusted_time":"","roots":[]}\n' \
      > "$SOVIEZ_OFFLINE_TRUST_STATE"
  fi
}

soviez_offline_trust_record_time() {
  local iso="${1:-}"
  soviez_offline_trust_state_init
  [[ -n "$iso" ]] || iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  SOVIEZ_S="$SOVIEZ_OFFLINE_TRUST_STATE" SOVIEZ_T="$iso" python3 - <<'PY'
import json, os
p=os.environ["SOVIEZ_S"]
d=json.load(open(p))
d["last_trusted_time"]=os.environ["SOVIEZ_T"]
open(p,"w").write(json.dumps(d, separators=(",", ":")))
PY
}

soviez_offline_trust_assert_clock() {
  local now_epoch last
  soviez_offline_trust_state_init
  if [[ -n "${SOVIEZ_PHASE23_CERT_CLOCK_EPOCH:-}" ]]; then
    if [[ "${SOVIEZ_TEST_MODE:-0}" != "1" && "${SOVIEZ_PHASE23_CERTIFICATION:-0}" != "1" ]]; then
      echo "OFFLINE_BUNDLE_CLOCK_ROLLBACK_DETECTED: cert clock forbidden in production" >&2
      return 1
    fi
    now_epoch="$SOVIEZ_PHASE23_CERT_CLOCK_EPOCH"
  else
    now_epoch="$(date -u +%s)"
  fi
  last="$(soviez_json_get "$(cat "$SOVIEZ_OFFLINE_TRUST_STATE")" last_trusted_time 2>/dev/null || true)"
  if [[ -n "$last" && "$last" != "null" ]]; then
    local last_epoch
    last_epoch="$(SOVIEZ_T="$last" python3 - <<'PY'
import os
from datetime import datetime
t=os.environ["SOVIEZ_T"].replace("Z","+00:00")
print(int(datetime.fromisoformat(t).timestamp()))
PY
)"
    if [[ "$((now_epoch + 300))" -lt "$last_epoch" ]]; then
      echo "OFFLINE_BUNDLE_CLOCK_ROLLBACK_DETECTED" >&2
      return 1
    fi
    if [[ "$now_epoch" -lt "$((last_epoch - 3600))" ]]; then
      echo "OFFLINE_BUNDLE_CLOCK_ROLLBACK_DETECTED" >&2
      return 1
    fi
  fi
  return 0
}
