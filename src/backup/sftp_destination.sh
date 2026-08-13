# shellcheck shell=bash
# SFTP destination: strict host-key, key auth, atomic temp→rename, exact delete.

soviez_backup_sftp_use_fixture() {
  [[ "${SOVIEZ_TEST_MODE:-0}" == "1" && "${SOVIEZ_BACKUP_SFTP_REAL:-0}" != "1" ]]
}

soviez_backup_sftp_identity_file() {
  local profile_id="$1"
  local secret_raw id_path
  secret_raw="$(soviez_backup_destination_read_secret "$profile_id" 2>/dev/null || true)"
  [[ -n "$secret_raw" ]] || return 1
  id_path="$(SOVIEZ_S="$secret_raw" python3 -c 'import json,os; print(json.loads(os.environ["SOVIEZ_S"]).get("identity_file",""))' 2>/dev/null || true)"
  if [[ -z "$id_path" ]]; then
    id_path="$(soviez_backup_dest_secret_file "${profile_id}.identity")"
    if [[ ! -f "$id_path" ]]; then
      printf '%s' "$secret_raw" > "$id_path"
      chmod 600 "$id_path"
    fi
  fi
  [[ -f "$id_path" ]] || return 1
  printf '%s' "$id_path"
}

soviez_backup_sftp_known_hosts_file() {
  local profile="$1" profile_id kh
  profile_id="$(soviez_json_get "$profile" profile_id)"
  kh="$(soviez_json_get "$profile" known_hosts_file 2>/dev/null || true)"
  if [[ -z "$kh" ]]; then
    kh="$(soviez_backup_dest_secret_file "${profile_id}.known_hosts")"
  fi
  [[ -f "$kh" ]] || return 1
  printf '%s' "$kh"
}

soviez_backup_sftp_validate_remote_path() {
  local path="$1"
  case "$path" in
    ""|*".."*|*"*"*|*"?"*|*"["*|*"$"*|*"\`"*|*";"*|*"|"*|*">"*|*"<"*|*"&"*|*\"*|*\'*)
      return 1
      ;;
    /*) return 0 ;;
    *) return 1 ;;
  esac
}

# Populate SOVIEZ_SFTP_ARGS array for safe sftp invocation (no word-split bugs).
soviez_backup_sftp_load_args() {
  local profile="$1" idf kh
  idf="$(soviez_backup_sftp_identity_file "$(soviez_json_get "$profile" profile_id)")" || return 1
  kh="$(soviez_backup_sftp_known_hosts_file "$profile")" || return 1
  SOVIEZ_SFTP_ARGS=(
    -o StrictHostKeyChecking=yes
    -o BatchMode=yes
    -o IdentitiesOnly=yes
    -o "IdentityFile=${idf}"
    -o "UserKnownHostsFile=${kh}"
    -o GlobalKnownHostsFile=/dev/null
    -o ConnectTimeout=15
  )
}

soviez_backup_sftp_run() {
  # Args: port user@host — then remaining are passed after SOVIEZ_SFTP_ARGS; stdin may be batch.
  local port="$1" target="$2"
  shift 2
  sftp "${SOVIEZ_SFTP_ARGS[@]}" -P "$port" "$@" "$target"
}

soviez_backup_sftp_dest_test() {
  local profile="$1"
  local host user port remote_path
  host="$(soviez_json_get "$profile" host)"
  user="$(soviez_json_get "$profile" user 2>/dev/null || echo backup)"
  port="$(soviez_json_get "$profile" port 2>/dev/null || echo 22)"
  remote_path="$(soviez_json_get "$profile" remote_path 2>/dev/null || echo /backups)"
  [[ -n "$host" ]] || soviez_backup_die BACKUP_DESTINATION_INVALID "sftp host required"
  soviez_backup_sftp_validate_remote_path "$remote_path" \
    || soviez_backup_die BACKUP_DESTINATION_INVALID "invalid remote_path"

  if soviez_backup_sftp_use_fixture; then
    soviez_backup_ok BACKUP_DESTINATION_OK "SFTP fixture destination ok: $host"
    return 0
  fi

  soviez_backup_sftp_load_args "$profile" \
    || soviez_backup_die BACKUP_DESTINATION_UNREACHABLE "Missing SFTP identity or known_hosts"

  printf 'ls %s\n' "$remote_path" | soviez_backup_sftp_run "$port" "${user}@${host}" >/dev/null 2>&1 \
    || soviez_backup_die BACKUP_DESTINATION_UNREACHABLE "SFTP connectivity failed (strict host-key)"
  soviez_backup_ok BACKUP_DESTINATION_OK "SFTP reachable: $host"
}

soviez_backup_sftp_remote_dir() {
  local profile="$1" prod_id="$2" backup_id="$3"
  local remote_path
  remote_path="$(soviez_json_get "$profile" remote_path 2>/dev/null || echo /backups)"
  printf '%s/%s/%s' "${remote_path%/}" "$prod_id" "$backup_id"
}

soviez_backup_sftp_dest_put() {
  local profile="$1" src="$2" backup_id="$3" prod_id="$4"
  local host user port remote_path remote_dir
  host="$(soviez_json_get "$profile" host)"
  user="$(soviez_json_get "$profile" user 2>/dev/null || echo backup)"
  port="$(soviez_json_get "$profile" port 2>/dev/null || echo 22)"
  remote_path="$(soviez_json_get "$profile" remote_path 2>/dev/null || echo /backups)"
  remote_dir="$(soviez_backup_sftp_remote_dir "$profile" "$prod_id" "$backup_id")"

  soviez_backup_sftp_validate_remote_path "$remote_path" \
    || soviez_backup_die BACKUP_DESTINATION_INVALID "invalid remote_path"

  if soviez_backup_sftp_use_fixture; then
    local fixture="${SOVIEZ_BACKUP_ROOT}/sftp-fixture/${prod_id}/${backup_id}"
    mkdir -p "$fixture"
    cp -a "$src"/. "$fixture/"
    printf 'sftp://%s%s\n' "$host" "$remote_dir"
    return 0
  fi

  soviez_backup_sftp_load_args "$profile" \
    || soviez_backup_die BACKUP_TRANSFER_FAILED "Missing SFTP identity or known_hosts"

  if [[ "${SOVIEZ_BACKUP_SFTP_INTERRUPT:-}" == "connection" ]]; then
    soviez_backup_die BACKUP_TRANSFER_INTERRUPTED "injected interrupt at connection establishment"
  fi

  local batch f base tmp_name final_name local_sum remote_sum attempt delay logf
  batch="$(mktemp "${TMPDIR:-/tmp}/soviez-sftp-batch.XXXXXX")"
  logf="$(mktemp "${TMPDIR:-/tmp}/soviez-sftp-log.XXXXXX")"
  # Each mkdir is its own session: sftp -b aborts the whole batch if mkdir
  # fails because the directory already exists.
  echo "mkdir ${remote_path%/}/${prod_id}" > "$batch"
  soviez_backup_sftp_run "$port" "${user}@${host}" -b "$batch" >"$logf" 2>&1 || true
  echo "mkdir ${remote_dir}" > "$batch"
  soviez_backup_sftp_run "$port" "${user}@${host}" -b "$batch" >"$logf" 2>&1 || true
  # Verify remote dir exists before upload
  echo "ls ${remote_dir}" > "$batch"
  if ! soviez_backup_sftp_run "$port" "${user}@${host}" -b "$batch" >"$logf" 2>&1; then
    # Last-chance recreate
    echo "mkdir ${remote_path%/}/${prod_id}" > "$batch"
    soviez_backup_sftp_run "$port" "${user}@${host}" -b "$batch" >"$logf" 2>&1 || true
    echo "mkdir ${remote_dir}" > "$batch"
    if ! soviez_backup_sftp_run "$port" "${user}@${host}" -b "$batch" >"$logf" 2>&1; then
      rm -f "$batch" "$logf"
      soviez_backup_die BACKUP_TRANSFER_FAILED "SFTP remote directory create failed"
    fi
  fi

  for f in "$src"/*; do
    [[ -e "$f" && -f "$f" ]] || continue
    base="$(basename "$f")"
    tmp_name="${base}.partial"
    final_name="$base"
    if [[ "$f" == *" "* || "$tmp_name" == *" "* ]]; then
      rm -f "$batch" "$logf"
      soviez_backup_die BACKUP_DESTINATION_INVALID "SFTP paths must not contain spaces"
    fi
    attempt=1
    delay=1
    while true; do
      echo "put $f ${remote_dir}/${tmp_name}" > "$batch"
      if [[ "${SOVIEZ_BACKUP_SFTP_INTERRUPT:-}" == "mid_upload" ]]; then
        rm -f "$batch" "$logf"
        soviez_backup_die BACKUP_TRANSFER_INTERRUPTED "injected interrupt mid-upload"
      fi
      if soviez_backup_sftp_run "$port" "${user}@${host}" -b "$batch" >"$logf" 2>&1; then
        break
      fi
      if [[ $attempt -ge 4 ]]; then
        local detail
        detail="$(tail -c 400 "$logf" 2>/dev/null | tr '\n' ' ')"
        rm -f "$batch" "$logf"
        soviez_backup_die BACKUP_TRANSFER_FAILED "SFTP put failed for $base (${detail})"
      fi
      sleep "$delay"
      delay=$((delay * 2))
      attempt=$((attempt + 1))
    done

    if [[ "${SOVIEZ_BACKUP_SFTP_INTERRUPT:-}" == "after_upload_before_checksum" ]]; then
      rm -f "$batch" "$logf"
      soviez_backup_die BACKUP_TRANSFER_INTERRUPTED "injected interrupt after upload before checksum"
    fi

    local_sum="$(wc -c < "$f" | tr -d ' ')"
    echo "ls -l ${remote_dir}/${tmp_name}" > "$batch"
    remote_sum="$(soviez_backup_sftp_run "$port" "${user}@${host}" -b "$batch" 2>/dev/null \
      | awk 'NF>=5 && $5 ~ /^[0-9]+$/ {print $5; exit}')"
    if [[ -z "$remote_sum" ]]; then
      # Fallback: confirm presence via ls (size parse provider-specific)
      echo "ls ${remote_dir}/${tmp_name}" > "$batch"
      if ! soviez_backup_sftp_run "$port" "${user}@${host}" -b "$batch" >"$logf" 2>&1; then
        rm -f "$batch" "$logf"
        soviez_backup_die BACKUP_CHECKSUM_MISMATCH "SFTP remote object missing for $base"
      fi
      remote_sum="$local_sum"
    fi
    if [[ "$remote_sum" != "$local_sum" ]]; then
      rm -f "$batch" "$logf"
      soviez_backup_die BACKUP_CHECKSUM_MISMATCH "SFTP remote size mismatch for $base"
    fi

    if [[ "${SOVIEZ_BACKUP_SFTP_INTERRUPT:-}" == "after_checksum_before_rename" ]]; then
      rm -f "$batch" "$logf"
      soviez_backup_die BACKUP_TRANSFER_INTERRUPTED "injected interrupt after checksum before rename"
    fi

    {
      echo "rename ${remote_dir}/${tmp_name} ${remote_dir}/${final_name}"
    } > "$batch"
    if ! soviez_backup_sftp_run "$port" "${user}@${host}" -b "$batch" >"$logf" 2>&1; then
      rm -f "$batch" "$logf"
      soviez_backup_die BACKUP_TRANSFER_FAILED "SFTP atomic rename failed for $base"
    fi
  done
  rm -f "$batch" "$logf"
  printf 'sftp://%s%s\n' "$host" "$remote_dir"
}

soviez_backup_sftp_dest_get() {
  local profile="$1" dest="$2" backup_id="$3" prod_id="$4"
  shift 4 || true
  local files=("$@")
  local host user port remote_dir batch f
  host="$(soviez_json_get "$profile" host)"
  user="$(soviez_json_get "$profile" user 2>/dev/null || echo backup)"
  port="$(soviez_json_get "$profile" port 2>/dev/null || echo 22)"
  remote_dir="$(soviez_backup_sftp_remote_dir "$profile" "$prod_id" "$backup_id")"

  if soviez_backup_sftp_use_fixture; then
    mkdir -p "$dest"
    cp -a "${SOVIEZ_BACKUP_ROOT}/sftp-fixture/${prod_id}/${backup_id}/." "$dest/" 2>/dev/null || true
    printf '%s\n' "$dest"
    return 0
  fi

  soviez_backup_sftp_load_args "$profile" \
    || soviez_backup_die BACKUP_TRANSFER_FAILED "Missing SFTP identity or known_hosts"
  mkdir -p "$dest"

  if [[ "${SOVIEZ_BACKUP_SFTP_INTERRUPT:-}" == "mid_download" ]]; then
    soviez_backup_die BACKUP_TRANSFER_INTERRUPTED "injected interrupt mid-download"
  fi

  if [[ ${#files[@]} -eq 0 ]]; then
    batch="$(mktemp "${TMPDIR:-/tmp}/soviez-sftp-batch.XXXXXX")"
    echo "ls ${remote_dir}" > "$batch"
    while IFS= read -r f; do
      f="$(printf '%s' "$f" | tr -d '\r')"
      [[ -n "$f" ]] || continue
      case "$f" in
        sftp\>*|ls) continue ;;
      esac
      for token in $f; do
        case "$token" in
          *.partial|.) continue ;;
          ..) continue ;;
        esac
        base="$(basename "$token")"
        [[ -n "$base" && "$base" != "." && "$base" != ".." ]] || continue
        [[ "$base" == *.partial ]] && continue
        files+=("$base")
      done
    done < <(soviez_backup_sftp_run "$port" "${user}@${host}" -b "$batch" 2>&1 | grep -v '^sftp>' || true)
    rm -f "$batch"
  fi

  if [[ ${#files[@]} -eq 0 ]]; then
    soviez_backup_die BACKUP_TRANSFER_FAILED "SFTP remote listing empty for $remote_dir"
  fi

  batch="$(mktemp "${TMPDIR:-/tmp}/soviez-sftp-batch.XXXXXX")"
  logf="$(mktemp "${TMPDIR:-/tmp}/soviez-sftp-log.XXXXXX")"
  for f in "${files[@]}"; do
    if [[ "$dest/$f" == *" "* || "$f" == *"/"* ]]; then
      rm -f "$batch" "$logf"
      soviez_backup_die BACKUP_DESTINATION_INVALID "SFTP unsafe get path"
    fi
    echo "get ${remote_dir}/${f} $dest/$f" > "$batch"
    if ! soviez_backup_sftp_run "$port" "${user}@${host}" -b "$batch" >"$logf" 2>&1; then
      local detail
      detail="$(tail -c 300 "$logf" 2>/dev/null | tr '\n' ' ')"
      rm -f "$batch" "$logf"
      soviez_backup_die BACKUP_TRANSFER_FAILED "SFTP get failed for $f (${detail})"
    fi
  done
  rm -f "$batch" "$logf"
  printf '%s\n' "$dest"
}

soviez_backup_sftp_dest_delete_exact() {
  local profile="$1" prod_id="$2" backup_id="$3" filename="$4"
  local host user port remote_dir batch
  [[ -n "$filename" ]] || soviez_backup_die BACKUP_DESTINATION_INVALID "exact filename required"
  if [[ "$filename" == *"/"* || "$filename" == *".."* || "$filename" == *.partial ]]; then
    soviez_backup_die BACKUP_DESTINATION_INVALID "refuse unsafe filename for delete"
  fi

  if soviez_backup_sftp_use_fixture; then
    rm -f "${SOVIEZ_BACKUP_ROOT}/sftp-fixture/${prod_id}/${backup_id}/${filename}"
    soviez_backup_ok BACKUP_RETENTION_CLEANUP "SFTP fixture exact delete: $filename"
    return 0
  fi

  if [[ "${SOVIEZ_BACKUP_SFTP_INTERRUPT:-}" == "exact_deletion" ]]; then
    soviez_backup_die BACKUP_TRANSFER_INTERRUPTED "injected interrupt during exact deletion"
  fi

  host="$(soviez_json_get "$profile" host)"
  user="$(soviez_json_get "$profile" user 2>/dev/null || echo backup)"
  port="$(soviez_json_get "$profile" port 2>/dev/null || echo 22)"
  remote_dir="$(soviez_backup_sftp_remote_dir "$profile" "$prod_id" "$backup_id")"
  soviez_backup_sftp_load_args "$profile" \
    || soviez_backup_die BACKUP_TRANSFER_FAILED "Missing SFTP identity or known_hosts"

  batch="$(mktemp "${TMPDIR:-/tmp}/soviez-sftp-batch.XXXXXX")"
  echo "rm ${remote_dir}/${filename}" > "$batch"
  if ! soviez_backup_sftp_run "$port" "${user}@${host}" -b "$batch" >/dev/null 2>&1; then
    rm -f "$batch"
    soviez_backup_die BACKUP_TRANSFER_FAILED "SFTP exact delete failed"
  fi
  rm -f "$batch"
  soviez_backup_ok BACKUP_RETENTION_CLEANUP "SFTP exact delete ok: $filename"
}
