#!/usr/bin/env bash
# Ubuntu 22.04/24.04 guest: quarantine cron snippet + network internal create.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
unset SOVIEZ_SH_ROOT
source "$ROOT/tests/helpers/s1_platform.sh"
s4_platform_source
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
export SOVIEZ_SH_ROOT="$ROOT" SOVIEZ_TEST_MODE=1
export SOVIEZ_SEC_QUARANTINE_ROOT
SOVIEZ_SEC_QUARANTINE_ROOT="$(mktemp -d)"
rid="$(s4_run_id)"
trap 'docker rm -f "${rid}-u22" "${rid}-u24" >/dev/null 2>&1 || true
      docker network rm "soviez-q-guest-${rid}" >/dev/null 2>&1 || true
      rm -rf "$SOVIEZ_SEC_QUARANTINE_ROOT"' EXIT

run_guest() {
  local tag="$1" name="$2"
  docker pull --platform linux/arm64 "$tag" >/dev/null
  docker run -d --name "$name" --platform linux/arm64 "$tag" sleep 3600 >/dev/null
  docker cp "$ROOT/src/security/quarantine/cron.sh" "$name:/tmp/cron.sh"
  docker exec "$name" bash -lc '
    set -euo pipefail
    source /tmp/cron.sh
    soviez_q_odoo_quarantine_conf_snippet | grep -q max_cron_threads
    echo GUEST_OK
  '
}

# Host-side archive validate (python available) + guest cron proof
tmp="$(mktemp -d)"
mkdir -p "$tmp/good" && echo x >"$tmp/good/f" && tar -C "$tmp/good" -cf "$tmp/g.tar" f
soviez_q_archive_validate "$tmp/g.tar" "$tmp/out" | grep -q PASS
python3 - "$tmp/bad.tar" <<'PY'
import tarfile,io,sys
tf=tarfile.open(sys.argv[1],"w")
info=tarfile.TarInfo("../../x")
info.size=1
tf.addfile(info, io.BytesIO(b"z"))
tf.close()
PY
set +e
soviez_q_archive_validate "$tmp/bad.tar" "$tmp/out2" >/dev/null 2>&1
arc=$?
set -e
[[ $arc -ne 0 ]]

# Internal network create works on docker host (used by guests indirectly)
export SOVIEZ_Q_TRUST=EXTERNAL_UNKNOWN
qid="$(soviez_q_create)"
# Force predictable name via network create
net="$(soviez_q_network_create "$qid")"
docker network inspect "$net" --format '{{json .Internal}}' | grep -q true

run_guest ubuntu:22.04 "${rid}-u22"
echo PASS ubuntu22
run_guest ubuntu:24.04 "${rid}-u24"
echo PASS ubuntu24
echo PASS
