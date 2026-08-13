#!/usr/bin/env bash
# Phase 16 final — real OpenSSH/SFTP strict host-key backup/download/delete + interrupts.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"

bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

FIX="$ROOT/.tmp/p16-fixtures"
docker info >/dev/null 2>&1 || { echo "FAIL: Docker required" >&2; exit 1; }

# Ensure SFTP fixture (recreate if orphaned after Colima reboot / missing network)
ensure_sftp() {
  docker network create soviez-p16-net >/dev/null 2>&1 || true
  mkdir -p "$FIX/sftp/keys"
  [[ -f "$FIX/sftp/keys/id_ed25519" ]] || ssh-keygen -t ed25519 -N '' -f "$FIX/sftp/keys/id_ed25519" -C p16 >/dev/null
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
    if ! docker start soviez-p16-sftp >/dev/null 2>&1; then
      docker rm -f soviez-p16-sftp >/dev/null 2>&1 || true
      docker run -d --name soviez-p16-sftp --network soviez-p16-net -p 2222:22 soviez-p16-sftp:local >/dev/null
    fi
  else
    docker run -d --name soviez-p16-sftp --network soviez-p16-net -p 2222:22 soviez-p16-sftp:local >/dev/null
  fi
}
refresh_sftp_host_keys() {
  local i
  for i in $(seq 1 40); do
    if nc -z 127.0.0.1 2222 2>/dev/null; then
      if ssh-keyscan -p 2222 127.0.0.1 2>/dev/null | grep -q ssh-; then
        ssh-keyscan -p 2222 127.0.0.1 2>/dev/null > "$FIX/sftp/known_hosts"
        chmod 600 "$FIX/sftp/known_hosts" "$FIX/sftp/keys/id_ed25519"
        return 0
      fi
    fi
    sleep 1
  done
  return 1
}
ensure_sftp
refresh_sftp_host_keys || { echo "FAIL: SFTP host keyscan failed" >&2; exit 1; }
# Connectivity smoke before suite (retry — sshd may still be binding; recreate on sticky fail)
smoke_ok=0
for i in $(seq 1 30); do
  if sftp -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$FIX/sftp/known_hosts" \
    -o GlobalKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ConnectTimeout=5 \
    -i "$FIX/sftp/keys/id_ed25519" -P 2222 -b /dev/stdin backup@127.0.0.1 <<<'pwd' >/dev/null 2>&1; then
    smoke_ok=1
    break
  fi
  sleep 1
  if (( i % 5 == 0 )); then
    docker rm -f soviez-p16-sftp >/dev/null 2>&1 || true
    ensure_sftp
  fi
  refresh_sftp_host_keys || true
done
[[ "$smoke_ok" -eq 1 ]] || { echo "FAIL: SFTP fixture not reachable" >&2; exit 1; }

export SOVIEZ_TEST_MODE=1
export SOVIEZ_BACKUP_SFTP_REAL=1
export SOVIEZ_BACKUP_PASSPHRASE="p16-sftp-real-passphrase-not-production"
export SOVIEZ_BACKUP_ASSUME_YES=1
export SOVIEZ_ROOT="$ROOT/.tmp/p16-sftp-real-$$"
rm -rf "$SOVIEZ_ROOT"
mkdir -p "$SOVIEZ_ROOT"
soviez_paths_init
soviez_ops_paths_init 2>/dev/null || true
soviez_backup_paths_init

HOST="$(hostname -f 2>/dev/null || hostname)"
PROD=prod-sftp-real
mkdir -p "$SOVIEZ_TENANT_DIR/$PROD/db" "$SOVIEZ_TENANT_DIR/$PROD/filestore"
printf 'fs\n' > "$SOVIEZ_TENANT_DIR/$PROD/filestore/a.bin"
printf 'db\n' > "$SOVIEZ_TENANT_DIR/$PROD/db/marker"
python3 - <<PY > "$SOVIEZ_TENANT_DIR/$PROD/identity.json"
import json
print(json.dumps({
  "tenant_id":"$PROD","license_id":"lic-sftp","database_uuid":"22222222-2222-2222-2222-222222222222",
  "database_name":"db_sftp_real","host_identity":"$HOST","fingerprint":"fp-$PROD",
  "production_fingerprint":"fp-$PROD","erp_major":"18",
  "filestore_path":"$SOVIEZ_TENANT_DIR/$PROD/filestore",
  "database_path":"$SOVIEZ_TENANT_DIR/$PROD/db",
  "current_digest":"sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
},separators=(",",":")))
PY

# Copy known_hosts + identity into secrets dir paths referenced by profile
KH="$SOVIEZ_BACKUP_SECRETS_DIR/sftp-real.known_hosts"
IDF="$SOVIEZ_BACKUP_SECRETS_DIR/sftp-real.identity"
mkdir -p "$SOVIEZ_BACKUP_SECRETS_DIR"
cp "$FIX/sftp/known_hosts" "$KH"
cp "$FIX/sftp/keys/id_ed25519" "$IDF"
chmod 600 "$KH" "$IDF"

soviez_backup_destination_write "$(python3 - <<PY
import json
print(json.dumps({
  "profile_id":"sftp-real","kind":"sftp","host":"127.0.0.1","port":2222,
  "user":"backup","remote_path":"/srv/backups",
  "known_hosts_file":"$KH",
},separators=(",",":")))
PY
)" >/dev/null
soviez_backup_destination_write_secret sftp-real "{\"identity_file\":\"$IDF\"}"

# Strict host-key: refuse wrong known_hosts
BADKH="$SOVIEZ_ROOT/bad_known_hosts"
printf '127.0.0.1 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\n' > "$BADKH"
chmod 600 "$BADKH"
soviez_backup_destination_write "$(python3 - <<PY
import json
print(json.dumps({
  "profile_id":"sftp-badhk","kind":"sftp","host":"127.0.0.1","port":2222,
  "user":"backup","remote_path":"/srv/backups","known_hosts_file":"$BADKH",
},separators=(",",":")))
PY
)" >/dev/null
soviez_backup_destination_write_secret sftp-badhk "{\"identity_file\":\"$IDF\"}"
# Host-key mismatch must fail (die uses exit — run in subshell)
set +e
bash -c '
  source "'"$ROOT"'/dist/soviez.sh"
  export SOVIEZ_TEST_MODE=1 SOVIEZ_BACKUP_SFTP_REAL=1 SOVIEZ_ROOT="'"$SOVIEZ_ROOT"'"
  soviez_paths_init; soviez_backup_paths_init
  soviez_backup_destination_test sftp-badhk
' >/dev/null 2>&1
brc=$?
set -e
[[ $brc -ne 0 ]] || { echo "host-key mismatch should fail" >&2; exit 1; }

# Never disable host-key checking in source
if grep -n 'StrictHostKeyChecking=no' "$ROOT/src/backup/sftp_destination.sh"; then
  echo "SFTP host-key bypass" >&2; exit 1
fi

soviez_backup_destination_test sftp-real | grep -q BACKUP_DESTINATION_OK

out="$(soviez_backup_run "$PROD" sftp-real full 1)"
echo "$out" | grep -q BACKUP_COMPLETED || { echo "sftp backup failed: $out" >&2; exit 1; }
BID="$(echo "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["backup_id"])')"

# Remote final files exist (no .partial left as sole artifact)
printf 'ls %s/%s\n' "$PROD" "$BID" | sftp -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile="$KH" -o GlobalKnownHostsFile=/dev/null -o IdentitiesOnly=yes \
  -i "$IDF" -P 2222 backup@127.0.0.1 2>/dev/null | tee "$SOVIEZ_ROOT/remote.ls"
! grep -q '\.partial' "$SOVIEZ_ROOT/remote.ls" || { echo "partial left as final" >&2; exit 1; }
grep -q . "$SOVIEZ_ROOT/remote.ls"

# Download
dl="$SOVIEZ_ROOT/sftp-dl"
profile="$(soviez_backup_destination_resolve sftp-real)"
soviez_backup_sftp_dest_get "$profile" "$dl" "$BID" "$PROD" >/dev/null
find "$dl" -type f | grep -q . || { echo "download empty" >&2; exit 1; }

# Exact delete one file
fname="$(find "$dl" -type f | head -1 | xargs -n1 basename)"
[[ -n "$fname" ]] || { echo "no downloaded file" >&2; exit 1; }
soviez_backup_sftp_dest_delete_exact "$profile" "$PROD" "$BID" "$fname" | grep -q BACKUP_RETENTION_CLEANUP

# Interrupts (die uses exit — always run in subshell)
irq_expect_fail() {
  local label="$1"
  shift
  set +e
  "$@" >/dev/null 2>&1
  local rc=$?
  set -e
  [[ $rc -ne 0 ]] || { echo "interrupt $label should fail" >&2; exit 1; }
}

irq_expect_fail connection bash -c '
  source "'"$ROOT"'/dist/soviez.sh"
  export SOVIEZ_TEST_MODE=1 SOVIEZ_BACKUP_SFTP_REAL=1 SOVIEZ_ROOT="'"$SOVIEZ_ROOT"'" SOVIEZ_BACKUP_SFTP_INTERRUPT=connection
  soviez_paths_init; soviez_backup_paths_init
  soviez_backup_sftp_dest_put "$(soviez_backup_destination_resolve sftp-real)" "'"$dl"'" irq1 "'"$PROD"'"
'
irq_expect_fail mid_upload bash -c '
  source "'"$ROOT"'/dist/soviez.sh"
  export SOVIEZ_TEST_MODE=1 SOVIEZ_BACKUP_SFTP_REAL=1 SOVIEZ_ROOT="'"$SOVIEZ_ROOT"'" SOVIEZ_BACKUP_SFTP_INTERRUPT=mid_upload
  soviez_paths_init; soviez_backup_paths_init
  soviez_backup_sftp_dest_put "$(soviez_backup_destination_resolve sftp-real)" "'"$dl"'" irq2 "'"$PROD"'"
'
irq_expect_fail after_upload_before_checksum bash -c '
  source "'"$ROOT"'/dist/soviez.sh"
  export SOVIEZ_TEST_MODE=1 SOVIEZ_BACKUP_SFTP_REAL=1 SOVIEZ_ROOT="'"$SOVIEZ_ROOT"'" SOVIEZ_BACKUP_SFTP_INTERRUPT=after_upload_before_checksum
  soviez_paths_init; soviez_backup_paths_init
  soviez_backup_sftp_dest_put "$(soviez_backup_destination_resolve sftp-real)" "'"$dl"'" irq3 "'"$PROD"'"
'
irq_expect_fail after_checksum_before_rename bash -c '
  source "'"$ROOT"'/dist/soviez.sh"
  export SOVIEZ_TEST_MODE=1 SOVIEZ_BACKUP_SFTP_REAL=1 SOVIEZ_ROOT="'"$SOVIEZ_ROOT"'" SOVIEZ_BACKUP_SFTP_INTERRUPT=after_checksum_before_rename
  soviez_paths_init; soviez_backup_paths_init
  soviez_backup_sftp_dest_put "$(soviez_backup_destination_resolve sftp-real)" "'"$dl"'" irq4 "'"$PROD"'"
'

printf 'ls %s/irq4\n' "$PROD" | sftp -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile="$KH" -o GlobalKnownHostsFile=/dev/null -o IdentitiesOnly=yes \
  -i "$IDF" -P 2222 backup@127.0.0.1 2>/dev/null | tee "$SOVIEZ_ROOT/irq4.ls" || true

irq_expect_fail mid_download bash -c '
  source "'"$ROOT"'/dist/soviez.sh"
  export SOVIEZ_TEST_MODE=1 SOVIEZ_BACKUP_SFTP_REAL=1 SOVIEZ_ROOT="'"$SOVIEZ_ROOT"'" SOVIEZ_BACKUP_SFTP_INTERRUPT=mid_download
  soviez_paths_init; soviez_backup_paths_init
  soviez_backup_sftp_dest_get "$(soviez_backup_destination_resolve sftp-real)" "'"$SOVIEZ_ROOT"'/dl2" "'"$BID"'" "'"$PROD"'"
'
irq_expect_fail exact_deletion bash -c '
  source "'"$ROOT"'/dist/soviez.sh"
  export SOVIEZ_TEST_MODE=1 SOVIEZ_BACKUP_SFTP_REAL=1 SOVIEZ_ROOT="'"$SOVIEZ_ROOT"'" SOVIEZ_BACKUP_SFTP_INTERRUPT=exact_deletion
  soviez_paths_init; soviez_backup_paths_init
  soviez_backup_sftp_dest_delete_exact "$(soviez_backup_destination_resolve sftp-real)" "'"$PROD"'" "'"$BID"'" "'"$fname"'"
'

# Failure: wrong key
WRONG="$SOVIEZ_ROOT/wrong_key"
ssh-keygen -t ed25519 -N '' -f "$WRONG" -C wrong >/dev/null
soviez_backup_destination_write_secret sftp-real "{\"identity_file\":\"$WRONG\"}"
irq_expect_fail wrong_key bash -c '
  source "'"$ROOT"'/dist/soviez.sh"
  export SOVIEZ_TEST_MODE=1 SOVIEZ_BACKUP_SFTP_REAL=1 SOVIEZ_ROOT="'"$SOVIEZ_ROOT"'"
  soviez_paths_init; soviez_backup_paths_init
  soviez_backup_destination_test sftp-real
'
soviez_backup_destination_write_secret sftp-real "{\"identity_file\":\"$IDF\"}"

# Shell injection in remote_path
set +e
soviez_backup_sftp_validate_remote_path '/srv/backups;rm -rf /' ; inj=$?
set -e
[[ $inj -ne 0 ]] || { echo "shell injection path accepted" >&2; exit 1; }

# Key leakage scan
if grep -R "BEGIN OPENSSH PRIVATE KEY" "$SOVIEZ_BACKUP_OPS_DIR" "$SOVIEZ_BACKUP_INVENTORY_DIR" 2>/dev/null; then
  echo "private key leaked into ops/inventory" >&2; exit 1
fi
if grep -n 'StrictHostKeyChecking=no' "$ROOT/dist/soviez.sh"; then
  echo "host-key bypass in dist" >&2; exit 1
fi

echo "PASS test_backup_sftp_real"
rm -rf "$SOVIEZ_ROOT"
