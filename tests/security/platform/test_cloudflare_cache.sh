#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/tests/helpers/s1_platform.sh"
s2_platform_source
export SOVIEZ_SH_ROOT="$ROOT"
ranges="$(soviez_cf_load_ranges | wc -l | tr -d ' ')"
[[ "$ranges" -ge 5 ]]
meta="$(soviez_cf_cache_meta)"
echo "$meta" | grep -q last_known_good
# Refresh without flag must fail and preserve LKG
if SOVIEZ_CF_ALLOW_NETWORK_REFRESH=0 soviez_cf_refresh_ranges 2>/dev/null; then
  echo FAIL refresh should require operator flag >&2; exit 1
fi
# Empty replacement forbidden: simulate by ensuring load still works after failed refresh
soviez_cf_load_ranges | head -1 | grep -q '/'
echo PASS
