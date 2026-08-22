# shellcheck shell=bash
# Platform self-update trust: mandatory Ed25519 public verification keys.

# Bundled staging/certification public keys (PEM). Private keys never ship here.
SOVIEZ_PLATFORM_TRUST_KEY_ID_STAGING_DEFAULT="soviez-platform-staging-2026-08"

soviez_platform_openssl() {
  if declare -F soviez_offline_openssl >/dev/null 2>&1; then
    local _o
    _o="$(soviez_offline_openssl 2>/dev/null || true)"
    if [[ -n "$_o" && -x "$_o" ]]; then
      printf '%s\n' "$_o"
      return 0
    fi
  fi
  local c
  for c in "${SOVIEZ_OPENSSL:-}" /opt/homebrew/bin/openssl /usr/local/opt/openssl@3/bin/openssl /usr/local/bin/openssl; do
    [[ -n "$c" && -x "$c" ]] || continue
    if "$c" version 2>/dev/null | grep -qi 'OpenSSL'; then
      printf '%s\n' "$c"
      return 0
    fi
  done
  command -v openssl
}

soviez_platform_trust_dir() {
  # Prefer bundled keys next to assembled payload / repo share/.
  local candidates=(
    "${SOVIEZ_PLATFORM_TRUST_DIR:-}"
    "${SOVIEZ_SH_ROOT:-}/share/platform-trust"
    "$(soviez_platform_current_dir 2>/dev/null || true)/trust"
    "/opt/soviez/platform/current/trust"
    "/usr/local/share/soviez/platform-trust"
  )
  local d
  for d in "${candidates[@]}"; do
    [[ -n "$d" && -d "$d" ]] || continue
    printf '%s\n' "$d"
    return 0
  done
  # Fallback: relative to this assembled script location is unreliable; empty.
  printf '\n'
}

soviez_platform_trust_pubkey_for_id() {
  local key_id="${1:-}"
  if [[ -n "${SOVIEZ_PLATFORM_TRUST_PUBKEY:-}" && -f "${SOVIEZ_PLATFORM_TRUST_PUBKEY}" ]]; then
    printf '%s\n' "$SOVIEZ_PLATFORM_TRUST_PUBKEY"
    return 0
  fi
  local dir
  dir="$(soviez_platform_trust_dir)"
  [[ -n "$dir" ]] || return 1
  if [[ -n "$key_id" ]]; then
    if [[ -f "${dir}/${key_id}.pub" ]]; then
      printf '%s\n' "${dir}/${key_id}.pub"
      return 0
    fi
    if [[ -f "${dir}/keys.json" ]]; then
      local path
      path="$(SOVIEZ_K="$key_id" python3 - "$dir/keys.json" <<'PY'
import json,os,sys
d=json.load(open(sys.argv[1],encoding="utf-8"))
kid=os.environ.get("SOVIEZ_K") or ""
keys=d.get("keys") or {}
if kid in keys:
  p=keys[kid].get("public_key_path") or keys[kid].get("path") or ""
  print(p)
else:
  print("")
PY
)"
      if [[ -n "$path" ]]; then
        [[ "$path" == /* ]] || path="${dir}/${path}"
        if [[ -f "$path" ]]; then
          printf '%s\n' "$path"
          return 0
        fi
      fi
    fi
    # Explicit unknown signer_key_id → fail closed (no silent fallback).
    return 1
  fi
  # No key id: default staging public key
  if [[ -f "${dir}/staging.ed25519.pub" ]]; then
    printf '%s\n' "${dir}/staging.ed25519.pub"
    return 0
  fi
  return 1
}

# Canonical signing bytes for a platform-release manifest.
# Signs JSON object with signature/signature_b64url/signed/signed_at removed,
# sort_keys=True, separators=(",",":") — UTF-8, no trailing newline.
soviez_platform_manifest_canonical_payload() {
  local manifest="$1"
  python3 - "$manifest" <<'PY'
import json,sys
m=json.load(open(sys.argv[1],encoding="utf-8"))
for k in ("signature","signature_b64url","signed","signed_at","signature_algorithm"):
    # Keep signature_algorithm OUT of signed payload? Spec says algorithm is in manifest;
    # include algorithm + key id in signed body for binding.
    pass
drop=("signature","signature_b64url","signed","signed_at")
body={k:v for k,v in m.items() if k not in drop}
print(json.dumps(body, sort_keys=True, separators=(",",":"), ensure_ascii=False), end="")
PY
}

soviez_platform_version_cmp() {
  # Echo: -1 if a<b, 0 if equal, 1 if a>b (sort -V semantics on numeric-ish versions).
  # Use printf '%s' so GNU printf never treats "-1" as an option.
  local a="${1#v}" b="${2#v}"
  if [[ "$a" == "$b" ]]; then
    printf '%s\n' '0'
    return 0
  fi
  local newest
  newest="$(printf '%s\n%s\n' "$a" "$b" | sort -V | tail -n1)"
  if [[ "$newest" == "$a" ]]; then
    printf '%s\n' '1'
  else
    printf '%s\n' '-1'
  fi
}

soviez_platform_ed25519_verify() {
  local payload="$1" signature_b64url="$2" pubkey="$3"
  local ossl sig_bin msgf pad padded
  ossl="$(soviez_platform_openssl)"
  [[ -f "$pubkey" ]] || {
    echo "[error] platform trust public key missing" >&2
    return 1
  }
  sig_bin="$(mktemp "${TMPDIR:-/tmp}/soviez-plat-sig.XXXXXX")"
  msgf="$(mktemp "${TMPDIR:-/tmp}/soviez-plat-msg.XXXXXX")"
  printf '%s' "$payload" >"$msgf"
  pad=$(( (4 - ${#signature_b64url} % 4) % 4 ))
  padded="$signature_b64url"
  while [[ $pad -gt 0 ]]; do padded="${padded}="; pad=$((pad - 1)); done
  if ! printf '%s' "$padded" | tr '_-' '/+' | "$ossl" base64 -d -A -out "$sig_bin" 2>/dev/null; then
    rm -f "$sig_bin" "$msgf"
    echo "[error] platform signature decode failed" >&2
    return 1
  fi
  local siglen
  siglen="$(wc -c <"$sig_bin" | tr -d ' ')"
  if [[ "$siglen" != "64" ]]; then
    rm -f "$sig_bin" "$msgf"
    echo "[error] platform signature length invalid (expected 64 Ed25519 bytes, got ${siglen})" >&2
    return 1
  fi
  if ! "$ossl" pkeyutl -verify -pubin -inkey "$pubkey" -rawin -in "$msgf" -sigfile "$sig_bin" >/dev/null 2>&1; then
    rm -f "$sig_bin" "$msgf"
    echo "[error] platform Ed25519 signature verification failed" >&2
    return 1
  fi
  rm -f "$sig_bin" "$msgf"
  return 0
}

soviez_platform_sign_payload() {
  # Release-control only: signs with private key path. Never called on customer hosts.
  local payload="$1" privkey="$2"
  local ossl sig_bin msgf
  ossl="$(soviez_platform_openssl)"
  [[ -f "$privkey" ]] || return 1
  sig_bin="$(mktemp "${TMPDIR:-/tmp}/soviez-plat-ssig.XXXXXX")"
  msgf="$(mktemp "${TMPDIR:-/tmp}/soviez-plat-smsg.XXXXXX")"
  printf '%s' "$payload" >"$msgf"
  if ! "$ossl" pkeyutl -sign -inkey "$privkey" -rawin -in "$msgf" -out "$sig_bin" 2>/dev/null; then
    rm -f "$sig_bin" "$msgf"
    return 1
  fi
  "$ossl" base64 -A -in "$sig_bin" | tr '+/' '-_' | tr -d '='
  rm -f "$sig_bin" "$msgf"
}
