#!/usr/bin/env bash
# Disposable Ubuntu 22.04/24.04 host integrity fixtures (does not mutate developer host).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/tests/helpers/s1_platform.sh"
s3_platform_source
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
export SOVIEZ_SH_ROOT="$ROOT"
rid="$(s3_run_id)"
trap 'docker rm -f "${rid}-u22" "${rid}-u24" >/dev/null 2>&1 || true' EXIT

run_guest() {
  local tag="$1" name="$2"
  docker pull --platform linux/arm64 "$tag" >/dev/null
  docker run -d --name "$name" --platform linux/arm64 "$tag" sleep 3600 >/dev/null
  docker cp "$ROOT/src/security/detection/host_integrity.sh" "$name:/tmp/host_integrity.sh"
  docker cp "$ROOT/src/security/detection/persistence_scan.sh" "$name:/tmp/persistence_scan.sh"
  docker exec "$name" bash -lc '
    set -euo pipefail
    source /tmp/host_integrity.sh
    source /tmp/persistence_scan.sh
    fx=$(mktemp -d)
    mkdir -p "$fx/etc" "$fx/etc/cron.d" "$fx/etc/systemd/system"
    export SOVIEZ_S3_HOST_FIXTURE_ROOT="$fx"
    out=$(mktemp -d)
    soviez_s3_host_integrity_scan "$out" >/dev/null
    test "$(cat "$out/STATUS")" = "PASS"
    echo "/tmp/evil.so" >"$fx/etc/ld.so.preload"
    out2=$(mktemp -d)
    set +e
    soviez_s3_host_integrity_scan "$out2" >/dev/null
    rc=$?
    set -e
    test "$rc" -ne 0
    test "$(cat "$out2/STATUS")" = "FAIL"
    : >"$fx/etc/ld.so.preload"
    echo "root:x:0:0:root:/root:/bin/bash" >"$fx/etc/passwd"
    echo "evil0:x:0:0:e:/:/bin/bash" >>"$fx/etc/passwd"
    out3=$(mktemp -d)
    set +e
    soviez_s3_host_integrity_scan "$out3" >/dev/null
    set -e
    test "$(cat "$out3/STATUS")" = "FAIL"
    echo GUEST_OK
  '
}

run_guest ubuntu:22.04 "${rid}-u22"
echo "PASS ubuntu22"
run_guest ubuntu:24.04 "${rid}-u24"
echo "PASS ubuntu24"
echo PASS
