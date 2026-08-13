# shellcheck shell=bash
# Security Gate S2 — Cloudflare IP source-of-truth + real_ip directives.

SOVIEZ_CF_CACHE_DIR="${SOVIEZ_CF_CACHE_DIR:-}"
SOVIEZ_CF_LKG_REL="share/security/cloudflare/ips-v4.lkg.json"

soviez_cf_cache_dir() {
  if [[ -n "${SOVIEZ_CF_CACHE_DIR:-}" ]]; then
    printf '%s\n' "$SOVIEZ_CF_CACHE_DIR"
    return 0
  fi
  local root="${SOVIEZ_SH_ROOT:-${SOVIEZ_ROOT:-.}}"
  local d="${root}/var/security/cloudflare"
  mkdir -p "$d" 2>/dev/null || d="${TMPDIR:-/tmp}/soviez-cf-cache"
  mkdir -p "$d"
  printf '%s\n' "$d"
}

soviez_cf_lkg_path() {
  local root="${SOVIEZ_SH_ROOT:-${SOVIEZ_ROOT:-.}}"
  local bundled="${root}/${SOVIEZ_CF_LKG_REL}"
  if [[ -f "$bundled" ]]; then
    printf '%s\n' "$bundled"
    return 0
  fi
  # Assembled dist may not embed share/; fall back to cache.
  local cache
  cache="$(soviez_cf_cache_dir)/ips-v4.lkg.json"
  printf '%s\n' "$cache"
}

soviez_cf_active_cache_path() {
  printf '%s/ips-v4.active.json\n' "$(soviez_cf_cache_dir)"
}

soviez_cf_load_ranges() {
  # Prints CIDR lines. Prefer active cache → LKG. Never return empty if LKG exists.
  local active lkg
  active="$(soviez_cf_active_cache_path)"
  lkg="$(soviez_cf_lkg_path)"
  local src=""
  if [[ -f "$active" ]]; then
    src="$active"
  elif [[ -f "$lkg" ]]; then
    src="$lkg"
  else
    echo "[error] security:SEC_WARN_EDGE_CACHE_STALE: no Cloudflare IP cache" >&2
    return 1
  fi
  python3 - "$src" <<'PY' 2>/dev/null || true
import json,sys
p=sys.argv[1]
d=json.load(open(p))
for r in d.get("ranges") or []:
    print(r)
PY
}

soviez_cf_cache_meta() {
  local active lkg src
  active="$(soviez_cf_active_cache_path)"
  lkg="$(soviez_cf_lkg_path)"
  if [[ -f "$active" ]]; then src="$active"; else src="$lkg"; fi
  [[ -f "$src" ]] || { echo "{}"; return 1; }
  python3 - "$src" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
print(json.dumps({
  "source": d.get("source"),
  "fetched_utc": d.get("fetched_utc"),
  "digest_sha256": d.get("digest_sha256"),
  "range_count": len(d.get("ranges") or []),
  "fallback": d.get("fallback","last_known_good"),
  "path": sys.argv[1],
}, indent=2))
PY
}

soviez_cf_refresh_ranges() {
  # Explicit operator-initiated only. No hidden periodic network refresh.
  # Usage: soviez_cf_refresh_ranges [--force]
  if [[ "${SOVIEZ_CF_ALLOW_NETWORK_REFRESH:-0}" != "1" ]]; then
    echo "[security] SEC_WARN_EDGE_CACHE_STALE: refresh requires SOVIEZ_CF_ALLOW_NETWORK_REFRESH=1 (operator-initiated)" >&2
    return 1
  fi
  local url="https://www.cloudflare.com/ips-v4"
  local tmp
  tmp="$(mktemp)"
  if ! curl -fsSL --max-time 15 "$url" -o "$tmp" 2>/dev/null; then
    echo "[security] SEC_WARN_EDGE_CACHE_STALE: fetch failed — preserving last-known-good" >&2
    rm -f "$tmp"
    return 1
  fi
  local count
  count="$(grep -cE '^[0-9]' "$tmp" || echo 0)"
  if [[ "$count" -lt 5 ]]; then
    echo "[security] SEC_WARN_EDGE_CACHE_STALE: fetched list too small — preserving LKG" >&2
    rm -f "$tmp"
    return 1
  fi
  local digest ts out
  digest="$(openssl dgst -sha256 "$tmp" | awk '{print $NF}')"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  out="$(soviez_cf_active_cache_path)"
  python3 - "$tmp" "$out" "$url" "$digest" "$ts" <<'PY'
import json,sys
ranges=[ln.strip() for ln in open(sys.argv[1]) if ln.strip() and not ln.startswith("#")]
obj={"source":sys.argv[3],"fetched_utc":sys.argv[5],"digest_sha256":sys.argv[4],"ranges":ranges,"fallback":"last_known_good"}
json.dump(obj, open(sys.argv[2],"w"), indent=2)
print(sys.argv[2])
PY
  rm -f "$tmp"
  chmod 600 "$out" 2>/dev/null || true
}

soviez_edge_cloudflare_real_ip_directives() {
  local r
  echo "# Cloudflare real_ip — trusted ranges only"
  echo "real_ip_header CF-Connecting-IP;"
  echo "real_ip_recursive on;"
  while IFS= read -r r; do
    [[ -n "$r" ]] || continue
    echo "set_real_ip_from ${r};"
  done < <(soviez_cf_load_ranges)
}

soviez_edge_trust_client_ip() {
  # Returns 0 if remote_addr is trusted proxy for current EDGE_MODE.
  local remote="$1"
  local mode="${SOVIEZ_EDGE_MODE:-direct}"
  case "$mode" in
    direct)
      # Direct: never treat arbitrary XFF as client; remote_addr is source of truth.
      return 0
      ;;
    cloudflare|cloudflare_aop)
      local r
      while IFS= read -r r; do
        [[ -n "$r" ]] || continue
        if python3 - "$remote" "$r" <<'PY'
import ipaddress,sys
ip=ipaddress.ip_address(sys.argv[1])
net=ipaddress.ip_network(sys.argv[2], strict=False)
sys.exit(0 if ip in net else 1)
PY
        then
          return 0
        fi
      done < <(soviez_cf_load_ranges)
      return 1
      ;;
    *)
      return 1
      ;;
  esac
}

soviez_edge_reject_spoofed_xff_policy() {
  # Document/check: in direct mode, generated nginx must not set_real_ip_from 0.0.0.0/0.
  local conf="${1:-}"
  if [[ -n "$conf" && -f "$conf" ]]; then
    if grep -E 'set_real_ip_from[[:space:]]+0\.0\.0\.0/0' "$conf" >/dev/null 2>&1; then
      echo "[error] security:SEC_CRIT_NGINX_INVALID: trusts entire internet as real_ip" >&2
      return 1
    fi
  fi
  return 0
}
