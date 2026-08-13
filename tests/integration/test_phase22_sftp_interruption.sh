#!/usr/bin/env bash
# Phase 22 G3 — SFTP archive upload/retrieve interruption + resume (real OpenSSH).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/phase22_cert.sh"
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/phase22_fixture.sh"
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"

bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

docker info >/dev/null 2>&1 || { echo "FAIL: Docker required"; exit 1; }
soviez_phase22_cert_env
export SOVIEZ_PHASE22_REQUIRE_HOST_REBOOT=0
export SOVIEZ_PHASE22_REQUIRE_REAL_S3=0
soviez_phase22_assert_cert_gates

FIX="$ROOT/.tmp/p16-fixtures"
ensure_sftp() {
  docker network create soviez-p16-net >/dev/null 2>&1 || true
  mkdir -p "$FIX/sftp/keys"
  [[ -f "$FIX/sftp/keys/id_ed25519" ]] || ssh-keygen -t ed25519 -N '' -f "$FIX/sftp/keys/id_ed25519" -C p22 >/dev/null
  cp "$FIX/sftp/keys/id_ed25519.pub" "$FIX/sftp/id_ed25519.pub"
  docker image inspect soviez-p16-sftp:local >/dev/null 2>&1 || {
    cat > "$FIX/sftp/Dockerfile" <<'EOF'
FROM alpine:3.20
RUN apk add --no-cache openssh-server openssh-sftp-server \
 && mkdir -p /var/run/sshd /srv/backups /home/backup/.ssh \
 && adduser -D -u 1001 -h /home/backup backup \
 && passwd -u backup 2>/dev/null || true \
 && ssh-keygen -A \
 && printf '%s\n' 'Port 22' 'PasswordAuthentication no' 'PubkeyAuthentication yes' \
  'PermitRootLogin no' 'AuthorizedKeysFile .ssh/authorized_keys' \
  'Subsystem sftp internal-sftp' 'Match User backup' \
  '  ForceCommand internal-sftp -d /srv/backups' '  AllowTcpForwarding no' > /etc/ssh/sshd_config
COPY id_ed25519.pub /home/backup/.ssh/authorized_keys
RUN chmod 700 /home/backup/.ssh && chmod 600 /home/backup/.ssh/authorized_keys \
 && chown -R backup:backup /home/backup /srv/backups
CMD ["/usr/sbin/sshd","-D","-e"]
EOF
    docker build -t soviez-p16-sftp:local "$FIX/sftp" >/dev/null
  }
  if docker inspect soviez-p16-sftp >/dev/null 2>&1; then
    docker start soviez-p16-sftp >/dev/null 2>&1 || {
      docker rm -f soviez-p16-sftp >/dev/null 2>&1 || true
      docker run -d --name soviez-p16-sftp --network soviez-p16-net -p 2222:22 soviez-p16-sftp:local >/dev/null
    }
  else
    docker run -d --name soviez-p16-sftp --network soviez-p16-net -p 2222:22 soviez-p16-sftp:local >/dev/null
  fi
}
ensure_sftp
for i in $(seq 1 40); do
  if nc -z 127.0.0.1 2222 2>/dev/null; then
    ssh-keyscan -p 2222 127.0.0.1 2>/dev/null > "$FIX/sftp/known_hosts" && break
  fi
  sleep 1
done
chmod 600 "$FIX/sftp/known_hosts" "$FIX/sftp/keys/id_ed25519" 2>/dev/null || true

cleanup() { soviez_phase22_fixture_cleanup_postgres 2>/dev/null || true; }
trap cleanup EXIT

soviez_phase22_fixture_init "$ROOT"
soviez_phase22_fixture_cutover >/dev/null
export SOVIEZ_CLI_CONFIRM_PHRASE="CLOSE ROLLBACK WINDOW ${CUTOVER_OP_ID}"
soviez_migration_stabilization_status "$CUTOVER_OP_ID" >/dev/null
export SOVIEZ_MIG_P22_FORCE_WINDOW_EXPIRED=1
soviez_migration_rollback_window_close "$CUTOVER_OP_ID" >/dev/null

soviez_backup_paths_init
KH="$SOVIEZ_BACKUP_SECRETS_DIR/p22-sftp.known_hosts"
IDF="$SOVIEZ_BACKUP_SECRETS_DIR/p22-sftp.identity"
mkdir -p "$SOVIEZ_BACKUP_SECRETS_DIR"
cp "$FIX/sftp/known_hosts" "$KH"
cp "$FIX/sftp/keys/id_ed25519" "$IDF"
chmod 600 "$KH" "$IDF"
soviez_backup_destination_write "$(python3 - <<PY
import json
print(json.dumps({
  "profile_id":"p22-sftp","kind":"sftp",
  "host":"127.0.0.1","port":2222,"user":"backup",
  "remote_path":"/srv/backups",
  "known_hosts_file":"$KH",
},separators=(",",":")))
PY
)" >/dev/null
soviez_backup_destination_write_secret p22-sftp "{\"identity_file\":\"$IDF\"}"

unset SOVIEZ_MIG_P22_ARCHIVE_SFTP_PROFILE
archive="$(soviez_migration_source_archive_start "$SOURCE_ID")"
ARCHIVE_OP="$(soviez_json_get "$archive" operation_id)"
export SOVIEZ_MIG_P22_ARCHIVE_SFTP_PROFILE=p22-sftp
export SOVIEZ_BACKUP_SFTP_REAL=1

export SOVIEZ_MIG_P22_SFTP_INTERRUPT=1
export SOVIEZ_BACKUP_SFTP_INTERRUPT=mid_upload
set +e
out="$(soviez_migration_p22_archive_store_remote "$ARCHIVE_OP" 2>&1)"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || { echo "FAIL: expected SFTP interrupt; out=$out"; exit 1; }
echo "$out" | grep -q MIGRATION_SOURCE_ARCHIVE_TRANSFER_INTERRUPTED || {
  echo "FAIL: missing interrupt code; out=$out" >&2; exit 1
}

unset SOVIEZ_MIG_P22_SFTP_INTERRUPT SOVIEZ_BACKUP_SFTP_INTERRUPT
export SOVIEZ_MIG_P22_SFTP_INTERRUPT=0
receipt="$(soviez_migration_p22_archive_store_remote "$ARCHIVE_OP")"
assert_eq "$(soviez_json_get "$receipt" status)" "stored" "sftp stored"
[[ -f "$(soviez_migration_p22_archive_op_dir "$ARCHIVE_OP")/archive_bundle.tar.enc" ]]
[[ -d "$SOVIEZ_ROOT/p22_source" ]]

echo "test_phase22_sftp_interruption: PASS"
