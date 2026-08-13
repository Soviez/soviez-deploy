#!/usr/bin/env bash
# Real Ubuntu guest: apt lock wait, no-kill proof (22.04 + 24.04).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
rid="corrapt-$(date +%s)-$RANDOM"
trap 'docker rm -f "${rid}-u22" "${rid}-u24" >/dev/null 2>&1 || true' EXIT

run_guest() {
  local image="$1" name="$2"
  docker pull --platform linux/arm64 "$image" >/dev/null
  docker run -d --name "$name" --privileged --platform linux/arm64 "$image" sleep 3600 >/dev/null
  docker cp "$ROOT/src/security/update_safety/apt_lock.sh" "$name:/tmp/apt_lock.sh"
  docker exec "$name" bash -s <<'GUEST'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
# Hold dpkg lock-frontend with flock + sleep (no package mutation).
bash -c 'exec 9>/var/lib/dpkg/lock-frontend; flock 9; sleep 25' >/tmp/lockhold.log 2>&1 &
HOLDER=$!
echo "$HOLDER" >/tmp/holder.pid
sleep 1
kill -0 "$HOLDER"
# shellcheck disable=SC1091
source /tmp/apt_lock.sh
export SOVIEZ_APT_LOCK_TIMEOUT=3
set +e
out="$(soviez_s5_apt_wait_for_lock 3 2>/tmp/wait.err)"
rc=$?
set -e
# Holder must still be alive (no kill)
if ! kill -0 "$HOLDER" 2>/dev/null; then
  echo "FAIL holder was killed" >&2
  exit 1
fi
if [[ "$out" != "PKG_LOCK_TIMEOUT" || "$rc" -eq 0 ]]; then
  echo "FAIL expected TIMEOUT got out=$out rc=$rc" >&2
  cat /tmp/wait.err >&2 || true
  exit 1
fi
[[ -e /var/lib/dpkg/lock-frontend ]]
kill "$HOLDER" 2>/dev/null || true
wait "$HOLDER" 2>/dev/null || true
sleep 1
out2="$(soviez_s5_apt_wait_for_lock 5 2>/dev/null || true)"
case "$out2" in
  PKG_LOCK_RELEASED|PKG_STATE_INCONSISTENT) ;;
  *) echo "FAIL expected RELEASED got $out2" >&2; exit 1 ;;
esac
echo "NO_KILL_PROOF_PASS"
GUEST
}

run_guest ubuntu:22.04 "${rid}-u22"
echo "PASS ubuntu22"
run_guest ubuntu:24.04 "${rid}-u24"
echo "PASS ubuntu24"
echo PASS
