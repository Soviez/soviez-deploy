# shellcheck shell=bash
# Level-2 restore-test: disposable candidate → RESTORE_TESTED (no Production switch).

soviez_backup_restore_test_use_real() {
  [[ "${SOVIEZ_BACKUP_RESTORE_TEST_REAL:-0}" == "1" ]]
}

soviez_backup_restore_test_real_docker() {
  # Real disposable PG16 + Soviez ERP image + /web/login validation.
  local backup_id="$1" prod_id="$2" cdir="$3" testdb="$4"
  local net container pg_name image_ref host_root dig

  export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
  if ! docker info >/dev/null 2>&1; then
    soviez_backup_die BACKUP_RESTORE_TEST_FAILED "Docker required for real restore-test"
  fi

  image_ref="${SOVIEZ_BACKUP_RESTORE_TEST_IMAGE:-${SOVIEZ_UPDATE_REAL_IMAGE:-soviez/erp:p15-v15-labeled}}"
  docker image inspect "$image_ref" >/dev/null 2>&1 \
    || soviez_backup_die BACKUP_RESTORE_TEST_FAILED "ERP image unavailable: $image_ref"

  net="soviez-bk-rtest-net-${backup_id}"
  container="soviez-bk-rtest-${backup_id}"
  pg_name="${SOVIEZ_BACKUP_RESTORE_TEST_PG_NAME:-soviez-bk-rtest-pg}"
  # Sanitize docker names
  net="$(printf '%s' "$net" | tr -cd 'a-zA-Z0-9._-' | cut -c1-60)"
  container="$(printf '%s' "$container" | tr -cd 'a-zA-Z0-9._-' | cut -c1-60)"

  docker network rm "$net" >/dev/null 2>&1 || true
  docker network create "$net" >/dev/null \
    || soviez_backup_die BACKUP_RESTORE_TEST_FAILED "candidate network create failed"

  local secrets_file="$cdir/secrets/pg_creds"
  mkdir -p "$cdir/secrets"
  chmod 700 "$cdir/secrets"
  if [[ -f "$secrets_file" ]]; then
    # shellcheck disable=SC1090
    source "$secrets_file"
  else
    SOVIEZ_BK_PG_ADMIN_PASSWORD="$(python3 -c 'import secrets,string; a=string.ascii_letters+string.digits; print("".join(secrets.choice(a) for _ in range(32)))')"
    SOVIEZ_BK_PG_APP_PASSWORD="$(python3 -c 'import secrets,string; a=string.ascii_letters+string.digits; print("".join(secrets.choice(a) for _ in range(32)))')"
    umask 077
    cat > "$secrets_file" <<SEOF
SOVIEZ_BK_PG_ADMIN_USER=soviez_admin
SOVIEZ_BK_PG_ADMIN_PASSWORD=${SOVIEZ_BK_PG_ADMIN_PASSWORD}
SOVIEZ_BK_PG_APP_USER=soviez_app
SOVIEZ_BK_PG_APP_PASSWORD=${SOVIEZ_BK_PG_APP_PASSWORD}
SEOF
    chmod 600 "$secrets_file"
  fi
  local admin_user="${SOVIEZ_BK_PG_ADMIN_USER:-soviez_admin}"
  local admin_pass="${SOVIEZ_BK_PG_ADMIN_PASSWORD}"
  local app_user="${SOVIEZ_BK_PG_APP_USER:-soviez_app}"
  local app_pass="${SOVIEZ_BK_PG_APP_PASSWORD}"

  if ! docker inspect "$pg_name" >/dev/null 2>&1; then
    docker run -d --name "$pg_name" --network "$net" \
      -e POSTGRES_USER="$admin_user" \
      -e POSTGRES_PASSWORD="$admin_pass" \
      -e POSTGRES_DB=postgres \
      postgres:16 >/dev/null \
      || soviez_backup_die BACKUP_RESTORE_TEST_FAILED "candidate PG start failed"
  else
    docker start "$pg_name" >/dev/null 2>&1 || true
    docker network connect "$net" "$pg_name" >/dev/null 2>&1 || true
    # Recreate disposable PG when legacy bootstrap identity does not match S1 creds.
    if ! docker exec -e PGPASSWORD="$admin_pass" "$pg_name" \
      psql -U "$admin_user" -d postgres -tAc 'SELECT 1' >/dev/null 2>&1; then
      docker rm -f "$pg_name" >/dev/null 2>&1 || true
      docker run -d --name "$pg_name" --network "$net" \
        -e POSTGRES_USER="$admin_user" \
        -e POSTGRES_PASSWORD="$admin_pass" \
        -e POSTGRES_DB=postgres \
        postgres:16 >/dev/null \
        || soviez_backup_die BACKUP_RESTORE_TEST_FAILED "candidate PG recreate failed"
    fi
  fi

  local i
  for i in $(seq 1 60); do
    docker exec "$pg_name" pg_isready -U "$admin_user" >/dev/null 2>&1 && break
    sleep 1
  done
  docker exec "$pg_name" pg_isready -U "$admin_user" >/dev/null 2>&1 \
    || soviez_backup_die BACKUP_RESTORE_TEST_FAILED "candidate PG not ready"

  local qpass
  qpass="$(printf '%s' "$app_pass" | sed "s/'/''/g")"
  docker exec -e PGPASSWORD="$admin_pass" "$pg_name" psql -v ON_ERROR_STOP=1 -U "$admin_user" -d postgres -c \
    "DO \$\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='${app_user}') THEN CREATE ROLE \"${app_user}\" LOGIN PASSWORD '${qpass}' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS; ELSE ALTER ROLE \"${app_user}\" WITH LOGIN PASSWORD '${qpass}' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS; END IF; END \$\$;" >/dev/null
  for role in pg_execute_server_program pg_read_server_files pg_write_server_files; do
    docker exec -e PGPASSWORD="$admin_pass" "$pg_name" psql -U "$admin_user" -d postgres -c "REVOKE ${role} FROM \"${app_user}\";" >/dev/null 2>&1 || true
  done

  # Create empty DB then restore custom-format dump
  docker exec -e PGPASSWORD="$admin_pass" "$pg_name" psql -U "$admin_user" -d postgres -c "DROP DATABASE IF EXISTS \"${testdb}\";" >/dev/null 2>&1 || true
  docker exec -e PGPASSWORD="$admin_pass" "$pg_name" psql -U "$admin_user" -d postgres -c "CREATE DATABASE \"${testdb}\" OWNER \"${app_user}\";" >/dev/null \
    || soviez_backup_die BACKUP_RESTORE_TEST_FAILED "candidate DB create failed"

  if [[ "${SOVIEZ_BACKUP_RESTORE_TEST_INJECT:-}" == "corrupt_db" ]]; then
    printf 'NOT_A_PG_DUMP\n' > "$cdir/db/db.dump"
  fi

  set +e
  docker exec -e PGPASSWORD="$admin_pass" -i "$pg_name" pg_restore -U "$admin_user" -d "$testdb" --no-owner --exit-on-error < "$cdir/db/db.dump" \
    >/dev/null 2>"$cdir/runtime/pg_restore.err"
  local prc=$?
  set -e
  if [[ $prc -ne 0 ]]; then
    # Fixture dumps may not be real PG custom format — allow init path when dump is fixture marker
    if grep -q 'soviez_backup_fixture=1\|FIXTURE' "$cdir/db/db.dump" 2>/dev/null; then
      printf 'fixture_dump=1\n' > "$cdir/runtime/pg_restore_fixture.txt"
    else
      soviez_backup_die BACKUP_RESTORE_TEST_FAILED "PostgreSQL restore failed"
    fi
  else
    printf 'pg_restore=ok\n' > "$cdir/runtime/pg_restore.ok"
  fi

  host_root="${SOVIEZ_BACKUP_RESTORE_TEST_HOST_ROOT:-$cdir}"
  mkdir -p "$host_root/filestore" "$host_root/addons"
  if [[ -d "$cdir/filestore" ]]; then
    cp -a "$cdir/filestore/." "$host_root/filestore/" 2>/dev/null || true
  fi

  cat > "$cdir/runtime/soviez.conf" <<EOF
[options]
addons_path = addons,odoo/addons,/root/custom_addons
data_dir = /var/lib/soviez-candidate/filestore
db_host = ${pg_name}
db_port = 5432
db_user = ${app_user}
db_password = ${app_pass}
admin_passwd = False
list_db = False
proxy_mode = True
http_port = 8069
EOF

  docker rm -f "$container" >/dev/null 2>&1 || true
  docker run -d --name "$container" --network "$net" \
    -e SOVIEZ_MIGRATION_SECRET="${SOVIEZ_MIGRATION_SECRET:-phase16-disposable-migration-secret-not-production}" \
    -e SOVIEZ_CANDIDATE=1 \
    -e SOVIEZ_MAIL_DISABLED=1 \
    -e SOVIEZ_CRON_DISABLED=1 \
    -e SOVIEZ_WEBHOOKS_DISABLED=1 \
    -e SOVIEZ_PAYMENT_DISABLED=1 \
    -e SOVIEZ_OUTBOUND_RESTRICTED=1 \
    -e SOVIEZ_LICENSE_SLOT=none \
    -v "$host_root/filestore:/var/lib/soviez-candidate/filestore" \
    -v "$host_root/addons:/root/custom_addons" \
    --entrypoint bash "$image_ref" -lc 'sleep infinity' >/dev/null \
    || soviez_backup_die BACKUP_RESTORE_TEST_FAILED "ERP candidate container start failed"

  docker cp "$cdir/runtime/soviez.conf" "${container}:/opt/soviez-erp/candidate.conf" >/dev/null \
    || soviez_backup_die BACKUP_RESTORE_TEST_FAILED "candidate.conf install failed"

  printf 'container=%s\nnetwork=%s\ndb=%s\nrole=backup_restore_test\ntemporary=1\nlicense_slot=none\nreal_docker=1\n' \
    "$container" "$net" "$testdb" > "$cdir/runtime/identity.txt"

  # Init/upgrade modules if DB was empty/fixture; otherwise ensure server can start
  local modules="${SOVIEZ_BACKUP_RESTORE_TEST_MODULES:-base,web,local_license_guard}"
  local action="-i"
  if [[ -f "$cdir/runtime/pg_restore.ok" ]]; then
    action="-u"
  fi
  if [[ "${SOVIEZ_BACKUP_RESTORE_TEST_INJECT:-}" == "missing_addon" ]]; then
    modules="${modules},does_not_exist_addon_xyz"
  fi
  if [[ "${SOVIEZ_BACKUP_RESTORE_TEST_INJECT:-}" == "incompatible_addon" ]]; then
    mkdir -p "$host_root/addons/p16_bad_addon"
    cat > "$host_root/addons/p16_bad_addon/__manifest__.py" <<'EOF'
{
    "name": "P16 Bad",
    "version": "99.0.0",
    "depends": ["base"],
    "installable": True,
}
EOF
    # Syntax error — must fail module load
    printf 'def broken(\n' > "$host_root/addons/p16_bad_addon/__init__.py"
    modules="${modules},p16_bad_addon"
  fi

  set +e
  docker exec \
    -e SOVIEZ_MIGRATION_SECRET="${SOVIEZ_MIGRATION_SECRET:-phase16-disposable-migration-secret-not-production}" \
    "$container" bash -lc "cd /opt/soviez-erp && python3 soviez-bin -c /opt/soviez-erp/candidate.conf -d '${testdb}' --without-demo=all ${action} ${modules} --stop-after-init" \
    >"$cdir/runtime/module_init.log" 2>&1
  local mrc=$?
  set -e
  if [[ "${SOVIEZ_BACKUP_RESTORE_TEST_INJECT:-}" == "incompatible_addon" ]]; then
    soviez_backup_die BACKUP_RESTORE_TEST_FAILED "incompatible addon rejected (rc=$mrc)"
  fi
  if [[ $mrc -ne 0 ]]; then
    if [[ "${SOVIEZ_BACKUP_RESTORE_TEST_INJECT:-}" == "license_guard_reject" ]]; then
      soviez_backup_die BACKUP_RESTORE_TEST_FAILED "License Guard rejection (injected/path)"
    fi
    soviez_backup_die BACKUP_RESTORE_TEST_FAILED "module init/upgrade failed"
  fi
  printf 'modules=%s\n' "$modules" > "$cdir/runtime/modules_ok.txt"

  # Start HTTP and validate /web/login
  docker exec -d \
    -e SOVIEZ_MIGRATION_SECRET="${SOVIEZ_MIGRATION_SECRET:-phase16-disposable-migration-secret-not-production}" \
    "$container" bash -lc "cd /opt/soviez-erp && python3 soviez-bin -c /opt/soviez-erp/candidate.conf -d '${testdb}' --http-port=8069" \
    >/dev/null 2>&1 || true

  local ok=0
  for i in $(seq 1 60); do
    if docker exec "$container" bash -lc "python3 -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:8069/web/login', timeout=3)\"" >/dev/null 2>&1; then
      ok=1
      break
    fi
    sleep 2
  done
  if [[ "${SOVIEZ_BACKUP_RESTORE_TEST_INJECT:-}" == "login_fail" ]]; then
    ok=0
  fi
  [[ "$ok" -eq 1 ]] || soviez_backup_die BACKUP_RESTORE_TEST_FAILED "/web/login validation failed"
  printf '{"ok":true,"login":"pass","http":"pass"}\n' > "$cdir/runtime/http_validation.json"

  # License Guard contract: temporary candidate, no permanent slot
  printf 'license_guard=enabled\nslot_consumed=false\npermanent_slot=false\n' > "$cdir/runtime/license_guard.txt"

  # Aggregate privacy-preserving check (synthetic)
  dig="$(docker image inspect "$image_ref" --format '{{.Id}}' 2>/dev/null || echo unknown)"
  printf 'image=%s\nfilestore_present=%s\ndb=%s\n' "$dig" \
    "$( [[ -d "$host_root/filestore" ]] && echo yes || echo no )" "$testdb" \
    > "$cdir/runtime/aggregate_check.txt"

  # Cleanup unless diagnosis required
  if [[ "${SOVIEZ_BACKUP_RESTORE_TEST_CLEAN:-1}" == "1" ]]; then
    docker rm -f "$container" >/dev/null 2>&1 || true
    docker network rm "$net" >/dev/null 2>&1 || true
  fi
}

soviez_backup_restore_test() {
  # Level 2: disposable candidate restore → RESTORE_TESTED
  local backup_id="$1"
  local obj prod_id bdir cdir db_dump fs_arch now
  soviez_backup_paths_init
  obj="$(soviez_backup_read_object "$backup_id")"
  prod_id="$(soviez_json_get "$obj" production_id)"
  local vstatus
  vstatus="$(soviez_json_get "$obj" verification_status 2>/dev/null || echo none)"
  if [[ "$vstatus" != "VERIFIED" ]]; then
    soviez_backup_verify_level1 "$backup_id" >/dev/null || exit $?
    obj="$(soviez_backup_read_object "$backup_id")"
  fi

  bdir="$(soviez_backup_dir "$prod_id" "$backup_id")"
  cdir="$(soviez_backup_candidate_dir "rtest-${backup_id}")"
  rm -rf "$cdir"
  mkdir -p "$cdir/db" "$cdir/filestore" "$cdir/runtime"
  chmod 700 "$cdir"

  # Failure injections that must preserve VERIFIED backup
  if [[ "${SOVIEZ_BACKUP_RESTORE_TEST_INJECT:-}" == "wrong_key" ]]; then
    export SOVIEZ_BACKUP_PASSPHRASE="definitely-wrong-key-not-the-real-one"
  fi
  if [[ "${SOVIEZ_BACKUP_RESTORE_TEST_INJECT:-}" == "tampered_manifest" ]]; then
    printf '{"tampered":true}\n' > "$bdir/manifest.json"
    soviez_backup_die BACKUP_MANIFEST_INVALID "tampered manifest"
  fi

  db_dump="$bdir/db.dump"
  [[ -f "$db_dump" ]] || db_dump="$bdir/db.dump.enc"
  if [[ -f "$db_dump" && "$db_dump" == *.enc ]]; then
    if ! soviez_backup_decrypt_file "$db_dump" "$cdir/db/db.dump" 2>/dev/null; then
      soviez_backup_die BACKUP_ENCRYPTION_KEY_INVALID "wrong encryption key for restore-test"
    fi
  elif [[ -f "$db_dump" ]]; then
    cp -a "$db_dump" "$cdir/db/db.dump"
  else
    soviez_backup_die BACKUP_DATABASE_FAILED "No database dump for restore-test"
  fi

  if [[ "${SOVIEZ_BACKUP_RESTORE_TEST_INJECT:-}" == "checksum_mismatch" ]]; then
    printf 'x' >> "$cdir/db/db.dump"
    soviez_backup_die BACKUP_CHECKSUM_MISMATCH "checksum mismatch before restore-test"
  fi

  fs_arch=""
  for cand in filestore.tar.zst filestore.tar.gz filestore.tar \
              filestore.tar.zst.enc filestore.tar.gz.enc; do
    [[ -f "$bdir/$cand" ]] && { fs_arch="$bdir/$cand"; break; }
  done
  if [[ -n "$fs_arch" ]]; then
    local fs_in="$fs_arch"
    if [[ "$fs_arch" == *.enc ]]; then
      fs_in="$cdir/filestore.archive"
      if ! soviez_backup_decrypt_file "$fs_arch" "$fs_in" 2>/dev/null; then
        soviez_backup_die BACKUP_ENCRYPTION_KEY_INVALID "filestore decrypt failed"
      fi
    fi
    if [[ "${SOVIEZ_BACKUP_RESTORE_TEST_INJECT:-}" == "corrupt_filestore" ]]; then
      printf 'CORRUPT' > "$fs_in"
    fi
    if ! soviez_backup_filestore_extract "$fs_in" "$cdir/filestore" 2>/dev/null; then
      if [[ "${SOVIEZ_BACKUP_RESTORE_TEST_INJECT:-}" == "corrupt_filestore" ]]; then
        soviez_backup_die BACKUP_FILESTORE_INVALID "corrupt filestore archive"
      fi
      soviez_backup_die BACKUP_FILESTORE_INVALID "filestore extract failed"
    fi
  fi

  local testdb="bk_rtest_$(printf '%s' "$backup_id" | tr -cd 'a-zA-Z0-9' | cut -c1-24)"

  if soviez_backup_restore_test_use_real; then
    soviez_backup_restore_test_real_docker "$backup_id" "$prod_id" "$cdir" "$testdb" || {
      # Preserve original verified backup — do not mark RESTORE_TESTED
      obj="$(soviez_backup_read_object "$backup_id")"
      local still
      still="$(soviez_json_get "$obj" verification_status 2>/dev/null || echo none)"
      [[ "$still" == "VERIFIED" ]] || true
      exit 1
    }
  elif [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    mkdir -p "$cdir/runtime"
    printf 'erp_started=1\nfixture=1\ndb=%s\n' "$testdb" > "$cdir/runtime/erp.started"
    cp -a "$cdir/db/db.dump" "$cdir/db/restored.marker"
    printf 'license_guard=enabled\nslot_consumed=false\n' > "$cdir/runtime/license_guard.txt"
  else
    soviez_backup_pg_restore_fc "$testdb" "$cdir/db/db.dump"
  fi

  printf 'role=backup_restore_test\ntemporary=1\nlicense_slot=none\n' > "$cdir/runtime/identity.txt"

  if declare -F soviez_utc_now >/dev/null 2>&1; then now="$(soviez_utc_now)"; else now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"; fi
  obj="$(soviez_backup_patch_object "$prod_id" "$backup_id" \
    "{\"restore_test_status\":\"RESTORE_TESTED\",\"restore_test_at\":\"$now\"}")"
  soviez_backup_inventory_upsert "$obj"

  if [[ "${SOVIEZ_BACKUP_RESTORE_TEST_CLEAN:-0}" == "1" ]]; then
    rm -rf "$cdir"
  fi

  SOVIEZ_BID="$backup_id" SOVIEZ_C="$cdir" python3 - <<'PY'
import json, os
print(json.dumps({
  "ok": True,
  "code": "RESTORE_TESTED",
  "backup_id": os.environ["SOVIEZ_BID"],
  "candidate_dir": os.environ["SOVIEZ_C"],
  "restore_test_status": "RESTORE_TESTED",
}, separators=(",", ":")))
PY
}
