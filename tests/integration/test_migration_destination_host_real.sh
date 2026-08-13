#!/usr/bin/env bash
# Phase 17 final — real Ubuntu amd64 destination host bootstrap (no OS/arch fixtures).
set -euo pipefail
# One automatic retry: qemu/amd64 Colima guests occasionally SIGSEGV with empty output under load.
if [[ "${SOVIEZ_P17_DEST_HOST_RETRY:-0}" != "1" ]]; then
  export SOVIEZ_P17_DEST_HOST_RETRY=1
  if bash "${BASH_SOURCE[0]}" "$@"; then
    exit 0
  fi
  echo "[warn] test_migration_destination_host_real: retrying once after failure" >&2
  exec bash "${BASH_SOURCE[0]}" "$@"
fi
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"

docker info >/dev/null 2>&1 || { echo "FAIL: Docker required"; exit 1; }

HOST_CTN="${SOVIEZ_P17_DEST_CTN:-soviez-p17-ubuntu2404}"
ensure_dest_host() {
  local name="$1" image="$2"
  docker network create soviez-p17-net >/dev/null 2>&1 || true
  docker volume create soviez-p17-sh >/dev/null 2>&1 || true
  docker volume create soviez-p17-persist >/dev/null 2>&1 || true
  if docker inspect "$name" >/dev/null 2>&1; then
    if docker start "$name" >/dev/null 2>&1; then
      return 0
    fi
    docker rm -f "$name" >/dev/null 2>&1 || true
  fi
  if [[ "$name" == "soviez-p17-ubuntu2404" ]]; then
    docker run -d --name "$name" --platform linux/amd64 --privileged \
      -v soviez-p17-sh:/soviez-sh:rw -v soviez-p17-persist:/var/lib/soviez:rw \
      "$image" sleep infinity >/dev/null
  else
    docker run -d --name "$name" --platform linux/amd64 --privileged \
      -v soviez-p17-sh:/soviez-sh:rw \
      "$image" sleep infinity >/dev/null
  fi
  docker exec "$name" bash -lc 'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && apt-get install -y -qq openssl python3 nginx ca-certificates >/dev/null'
}
ensure_dest_host "$HOST_CTN" ubuntu:24.04
ensure_dest_host soviez-p17-ubuntu2204 ubuntu:22.04
docker inspect "$HOST_CTN" >/dev/null 2>&1 || { echo "FAIL: missing disposable host $HOST_CTN"; exit 1; }

# Prove guest is real Ubuntu amd64 (not Darwin fixture)
ARCH="$(docker exec "$HOST_CTN" uname -m)"
OSLINE="$(docker exec "$HOST_CTN" bash -lc '. /etc/os-release; echo ${ID}:${VERSION_ID}')"
[[ "$ARCH" == "x86_64" ]] || { echo "FAIL arch=$ARCH"; exit 1; }
[[ "$OSLINE" == "ubuntu:24.04" || "$OSLINE" == "ubuntu:22.04" ]] || { echo "FAIL os=$OSLINE"; exit 1; }

# Assemble on host; sync into guest volume (Colima bind mounts of host paths are unreliable)
bash "$ROOT/build/assemble.sh" >/dev/null
docker exec "$HOST_CTN" mkdir -p /soviez-sh/dist
docker cp "$ROOT/dist/soviez.sh" "$HOST_CTN:/soviez-sh/dist/soviez.sh"
# Keep Ubuntu 22.04 guest in sync when present
if docker inspect soviez-p17-ubuntu2204 >/dev/null 2>&1; then
  docker exec soviez-p17-ubuntu2204 mkdir -p /soviez-sh/dist
  docker cp "$ROOT/dist/soviez.sh" "soviez-p17-ubuntu2204:/soviez-sh/dist/soviez.sh"
fi

docker exec "$HOST_CTN" bash -lc '
set -euo pipefail
test -f /soviez-sh/dist/soviez.sh
cd /soviez-sh
# shellcheck source=/dev/null
source /soviez-sh/dist/soviez.sh
export SOVIEZ_TEST_MODE=1
export SOVIEZ_MIG_REQUIRE_REAL_HOST=1
export SOVIEZ_MIG_ASSUME_YES=1
unset SOVIEZ_MIG_FIXTURE_OS_ID SOVIEZ_MIG_FIXTURE_ARCH SOVIEZ_MIG_FIXTURE_DOCKER_OK SOVIEZ_MIG_FIXTURE_COMPOSE_OK SOVIEZ_MIG_FIXTURE_NGINX_OK || true
export SOVIEZ_ROOT=/tmp/soviez-p17-dest-$$
mkdir -p "$SOVIEZ_ROOT"
soviez_paths_init
soviez_ops_paths_init 2>/dev/null || true
soviez_migration_paths_init
soviez_device_ensure_keys
DIGEST="sha256:$(printf real-host | openssl dgst -sha256 | awk "{print \$NF}")"
export SOVIEZ_MIG_EXPECTED_IMAGE_DIGEST="$DIGEST"
# No OS/arch fixtures — detect from guest
PRE="$(soviez_migration_bootstrap_preflight)"
echo "$PRE" | grep -q "ubuntu:" || { echo "FAIL preflight os"; exit 1; }
echo "$PRE" | grep -q "\"architecture\":\"amd64\"" || { echo "FAIL preflight arch"; exit 1; }
echo "$PRE" | grep -q "\"nginx_ok\":true" || { echo "FAIL nginx"; exit 1; }
BOOT="$(soviez_migration_bootstrap_run 1)"
echo "$BOOT" | grep -q "\"production_activated\":false" || { echo "FAIL activated"; exit 1; }
echo "$BOOT" | grep -q "\"non_slot_consuming\":true" || { echo "FAIL slot"; exit 1; }
echo "$BOOT" | grep -q "\"non_sellable\":true" || { echo "FAIL sellable"; exit 1; }
echo "$BOOT" | grep -q "\"migration_token_consumed\":false" || { echo "FAIL token"; exit 1; }
BID="$(python3 -c "import json,sys; print(json.load(sys.stdin)[\"bootstrap_id\"])" <<<"$BOOT")"
echo "$BID" > "$SOVIEZ_ROOT/bootstrap_id.txt"
echo "$SOVIEZ_ROOT" > /tmp/soviez-p17-last-root
echo PASS_BOOTSTRAP
'

# Host reboot: persist SOVIEZ_ROOT on named volume /var/lib/soviez (survives container restart).
docker exec "$HOST_CTN" bash -lc '
set -euo pipefail
cd /soviez-sh
source dist/soviez.sh
export SOVIEZ_TEST_MODE=1 SOVIEZ_MIG_REQUIRE_REAL_HOST=1 SOVIEZ_MIG_ASSUME_YES=1
unset SOVIEZ_MIG_FIXTURE_OS_ID SOVIEZ_MIG_FIXTURE_ARCH || true
export SOVIEZ_ROOT=/var/lib/soviez/p17-dest-persist
rm -rf "$SOVIEZ_ROOT"; mkdir -p "$SOVIEZ_ROOT"
soviez_paths_init; soviez_ops_paths_init 2>/dev/null || true; soviez_migration_paths_init; soviez_device_ensure_keys
export SOVIEZ_MIG_EXPECTED_IMAGE_DIGEST="sha256:$(printf persist | openssl dgst -sha256 | awk "{print \$NF}")"
BOOT="$(soviez_migration_bootstrap_run 1)"
python3 -c "import json,sys; print(json.load(sys.stdin)[\"bootstrap_id\"])" <<<"$BOOT" > "$SOVIEZ_ROOT/bootstrap_id.txt"
python3 -c "import json,sys; print(json.load(sys.stdin)[\"operation_id\"])" <<<"$BOOT" > "$SOVIEZ_ROOT/op_id.txt"
'

docker restart "$HOST_CTN" >/dev/null
sleep 3
docker exec "$HOST_CTN" bash -lc '
set -euo pipefail
# nginx may need re-start after container restart (packages persist only if volume-backed; reinstall soft-deps)
command -v openssl >/dev/null || true
cd /soviez-sh
source dist/soviez.sh
export SOVIEZ_TEST_MODE=1 SOVIEZ_ROOT=/var/lib/soviez/p17-dest-persist
soviez_paths_init; soviez_migration_paths_init
BID="$(cat "$SOVIEZ_ROOT/bootstrap_id.txt")"
OBJ="$(soviez_migration_bootstrap_dir "$BID")/object.json"
[[ -f "$OBJ" ]] || { echo "FAIL bootstrap missing after reboot"; exit 1; }
grep -q "\"production_activated\":false" "$OBJ"
# recovery_required path
OP="$(cat "$SOVIEZ_ROOT/op_id.txt")"
mkdir -p "$SOVIEZ_MIG_ROOT/ops/$OP"
printf "{\"operation_id\":\"%s\",\"operation_type\":\"migration_destination_bootstrap\",\"current_state\":\"recovery_required\"}\n" "$OP" > "$SOVIEZ_MIG_ROOT/ops/$OP/state.json"
export SOVIEZ_CLI_OP_ID="$OP"
OUT="$(soviez_cmd_migration_recover)"
echo "$OUT" | grep -q recovery_required
echo PASS_REBOOT
'

# Ubuntu 22.04 second host if present
if docker inspect soviez-p17-ubuntu2204 >/dev/null 2>&1; then
  docker exec soviez-p17-ubuntu2204 bash -lc '
  set -euo pipefail
  cd /soviez-sh; source dist/soviez.sh
  export SOVIEZ_TEST_MODE=1 SOVIEZ_MIG_REQUIRE_REAL_HOST=1 SOVIEZ_MIG_ASSUME_YES=1
  unset SOVIEZ_MIG_FIXTURE_OS_ID SOVIEZ_MIG_FIXTURE_ARCH || true
  export SOVIEZ_ROOT=/tmp/p17-2204-$$
  soviez_paths_init; soviez_migration_paths_init; soviez_device_ensure_keys
  export SOVIEZ_MIG_EXPECTED_IMAGE_DIGEST="sha256:$(printf u2204 | openssl dgst -sha256 | awk "{print \$NF}")"
  PRE="$(soviez_migration_bootstrap_preflight)"
  echo "$PRE" | grep -q "ubuntu:22.04"
  echo "$PRE" | grep -q "\"architecture\":\"amd64\""
  echo PASS_2204
  '
fi

# Unsupported arch denial (negative) — die() uses exit; must run in subshell
docker exec "$HOST_CTN" bash -lc '
set -euo pipefail
cd /soviez-sh; source dist/soviez.sh
export SOVIEZ_TEST_MODE=1 SOVIEZ_MIG_REQUIRE_REAL_HOST=0
export SOVIEZ_MIG_FIXTURE_OS_ID=ubuntu:24.04 SOVIEZ_MIG_FIXTURE_ARCH=arm64
export SOVIEZ_ROOT=/tmp/p17-neg-$$; soviez_paths_init; soviez_migration_paths_init
if ( soviez_migration_bootstrap_preflight >/dev/null 2>&1 ); then echo FAIL_ARM; exit 1; fi
echo PASS_ARM_DENY
'

echo "test_migration_destination_host_real: PASS"
