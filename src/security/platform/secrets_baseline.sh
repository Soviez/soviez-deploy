# shellcheck shell=bash
# Security Gate S1 — secret generation / file baseline.
#
# Residual risk (documented): docker container env may still hold *app* secrets
# (not bootstrap admin). Inspect-visible to host root. Bootstrap password must
# never be passed to Odoo env/argv.

soviez_sec_secret_gen() {
  local len="${1:-32}"
  if ! [[ "$len" =~ ^[0-9]+$ ]] || [[ "$len" -lt 16 ]]; then
    echo "[error] security:SEC_CRIT_WEAK_ADMIN_CREDENTIAL: secret length must be >= 16" >&2
    return 1
  fi
  python3 -c "import secrets,string; a=string.ascii_letters+string.digits; print(''.join(secrets.choice(a) for _ in range(int('${len}'))))"
}

soviez_sec_secret_write() {
  local path="$1" value="$2"
  local parent
  parent="${path%/*}"
  [[ "$parent" == "$path" ]] && parent="."
  mkdir -p "$parent"
  chmod 700 "$parent" 2>/dev/null || true
  umask 077
  printf '%s' "$value" >"$path"
  chmod 600 "$path"
}
