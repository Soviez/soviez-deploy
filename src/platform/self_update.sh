# shellcheck shell=bash
# Signed Soviez.sh platform self-update (NOT ERP product update).
# Connected path: mandatory Ed25519 + SHA256 (fail closed). No unsigned fallback.

soviez_platform_cmd_is_mutating() {
  case "${1:-}" in
    new|stage|stage-reattach|update|restore|restore-as-stage|security-harden|\
    migration-bootstrap-destination|migration-pair|migration-transfer-start|\
    migration-activate-destination|migration-cutover-start|migration-cutover-rollback|\
    tune|platform-install|ssl-renew|ssl-repair|backup|backup-import|backup-delete|\
    backup-retention-cleanup|stage-drop|stage-retention-run|stage-retention-extend)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

soviez_platform_cmd_is_readonly() {
  case "${1:-}" in
    version|list|stage-list|stage-status|operations-list|operation-status|operation-logs|\
    security-status|security-report|ssl-status|backup-list|backup-show|backup-verify|\
    backup-retention-status|backup-destination-list|help|"")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

soviez_platform_manifest_url() {
  if [[ -n "${SOVIEZ_PLATFORM_MANIFEST_URL:-}" ]]; then
    printf '%s\n' "$SOVIEZ_PLATFORM_MANIFEST_URL"
    return 0
  fi
  local channel
  channel="$(soviez_platform_channel)"
  # Default customer channel remains stable on main; staging/certification use explicit channel.
  printf 'https://raw.githubusercontent.com/Soviez/soviez-deploy/main/platform-release/%s/manifest.json\n' "$channel"
}

soviez_platform_lock_acquire() {
  local lock
  lock="$(soviez_platform_lock_path)"
  mkdir -p "$(dirname "$lock")"
  exec 9>"$lock"
  if ! flock -n 9; then
    echo "[info] waiting for platform update lock..." >&2
    flock 9
  fi
}

soviez_platform_lock_release() {
  flock -u 9 2>/dev/null || true
}

# Verify candidate: Ed25519 (mandatory) AND SHA256 (mandatory). Fail closed.
soviez_platform_verify_candidate() {
  local candidate="$1" manifest="$2"
  [[ -f "$candidate" && -f "$manifest" ]] || {
    echo "[error] platform verify: candidate or manifest missing" >&2
    return 1
  }

  local schema algo key_id signed signature expected actual channel version
  schema="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1],encoding="utf-8")).get("schema") or "")' "$manifest")"
  algo="$(python3 -c 'import json,sys; print((json.load(open(sys.argv[1],encoding="utf-8")).get("signature_algorithm") or "").lower())' "$manifest")"
  key_id="$(python3 -c 'import json,sys; m=json.load(open(sys.argv[1],encoding="utf-8")); print(m.get("signer_key_id") or m.get("key_id") or "")' "$manifest")"
  signed="$(python3 -c 'import json,sys; print(str(json.load(open(sys.argv[1],encoding="utf-8")).get("signed","")).lower())' "$manifest")"
  signature="$(python3 -c 'import json,sys; m=json.load(open(sys.argv[1],encoding="utf-8")); print(m.get("signature_b64url") or m.get("signature") or "")' "$manifest")"
  expected="$(python3 -c 'import json,sys; m=json.load(open(sys.argv[1],encoding="utf-8")); print((m.get("sha256") or m.get("digest") or "").replace("sha256:",""))' "$manifest")"
  version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1],encoding="utf-8")).get("version") or "")' "$manifest")"
  channel="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1],encoding="utf-8")).get("channel") or "")' "$manifest")"

  if [[ -z "$schema" || "$schema" != soviez.platform_release.v1 ]]; then
    echo "[error] platform security: malformed manifest schema=${schema:-missing}" >&2
    return 1
  fi
  if [[ "$signed" != "true" && "$signed" != "1" ]]; then
    echo "[error] platform security: manifest not marked signed" >&2
    return 1
  fi
  if [[ -z "$signature" ]]; then
    echo "[error] platform security: missing Ed25519 signature" >&2
    return 1
  fi
  case "$signature" in
    ok|valid|fixture|tampered|invalid|INVALID|TAMPERED)
      echo "[error] platform security: non-cryptographic signature refused" >&2
      return 1
      ;;
  esac
  if [[ "$algo" != "ed25519" ]]; then
    echo "[error] platform security: unsupported signature_algorithm=${algo:-missing} (required ed25519)" >&2
    return 1
  fi
  if [[ -z "$expected" || ${#expected} -ne 64 ]]; then
    echo "[error] platform security: missing/invalid sha256 in manifest" >&2
    return 1
  fi
  if [[ -z "$version" ]]; then
    echo "[error] platform security: manifest missing version" >&2
    return 1
  fi

  local pubkey
  if ! pubkey="$(soviez_platform_trust_pubkey_for_id "$key_id")"; then
    echo "[error] platform security: no trusted public key for signer_key_id=${key_id:-unknown}" >&2
    return 1
  fi

  local payload
  payload="$(soviez_platform_manifest_canonical_payload "$manifest")" || {
    echo "[error] platform security: cannot build canonical signing payload" >&2
    return 1
  }
  if ! soviez_platform_ed25519_verify "$payload" "$signature" "$pubkey"; then
    return 1
  fi

  if declare -F soviez_sha256_file >/dev/null 2>&1; then
    actual="$(soviez_sha256_file "$candidate")"
  else
    actual="$(shasum -a 256 "$candidate" | awk '{print $1}')"
  fi
  if [[ "$actual" != "$expected" ]]; then
    echo "[error] platform security: SHA256 mismatch expected=$expected actual=$actual" >&2
    return 1
  fi

  # Candidate must embed the claimed version (when assembled header present).
  if grep -q 'version:' "$candidate" 2>/dev/null; then
    local embedded
    embedded="$(grep -E '^# version:' "$candidate" | head -1 | sed 's/^# version:[[:space:]]*//' | tr -d '[:space:]')"
    if [[ -n "$embedded" && "$embedded" != "$version" ]]; then
      echo "[error] platform security: candidate version mismatch manifest=$version embedded=$embedded" >&2
      return 1
    fi
  fi

  # Channel binding when present
  if [[ -n "$channel" && -n "${SOVIEZ_PLATFORM_CHANNEL:-}" && "$channel" != "${SOVIEZ_PLATFORM_CHANNEL}" ]]; then
    if [[ "${SOVIEZ_PLATFORM_ALLOW_CHANNEL_MISMATCH:-0}" != "1" ]]; then
      echo "[error] platform security: channel mismatch manifest=$channel local=${SOVIEZ_PLATFORM_CHANNEL}" >&2
      return 1
    fi
  fi
  return 0
}

soviez_platform_fetch_manifest() {
  local out="$1"
  local url
  url="$(soviez_platform_manifest_url)"
  if [[ -n "${SOVIEZ_PLATFORM_MANIFEST_FILE:-}" && -f "${SOVIEZ_PLATFORM_MANIFEST_FILE}" ]]; then
    cp -f "$SOVIEZ_PLATFORM_MANIFEST_FILE" "$out"
    return 0
  fi
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" && -f "${SOVIEZ_ROOT:-}/platform-manifest.json" ]]; then
    cp -f "${SOVIEZ_ROOT}/platform-manifest.json" "$out"
    return 0
  fi
  command -v curl >/dev/null 2>&1 || return 1
  curl -fsSL --connect-timeout 3 --max-time 30 "$url" -o "$out"
}

soviez_platform_self_update_maybe() {
  local cmd="${SOVIEZ_CLI_COMMAND:-}"
  if [[ "${SOVIEZ_SKIP_PLATFORM_UPDATE:-}" == "1" ]]; then
    return 0
  fi

  local require_update=0
  local readonly=0
  if soviez_platform_cmd_is_mutating "$cmd"; then
    require_update=1
  elif soviez_platform_cmd_is_readonly "$cmd"; then
    readonly=1
  fi

  if [[ "${SOVIEZ_OFFLINE:-0}" == "1" ]]; then
    return 0
  fi

  local tmp_man
  tmp_man="$(mktemp)"
  if ! soviez_platform_fetch_manifest "$tmp_man"; then
    rm -f "$tmp_man"
    # Network/service unavailable — never block read-only; mutating continues unless STRICT.
    if [[ "$readonly" -eq 1 ]]; then
      return 0
    fi
    if [[ "$require_update" -eq 1 && "${SOVIEZ_PLATFORM_UPDATE_STRICT:-0}" == "1" ]]; then
      echo "[error] platform update service unavailable (network/manifest unreachable)" >&2
      return 1
    fi
    echo "[warn] platform update check skipped (service unavailable); continuing with installed platform" >&2
    return 0
  fi

  # Malformed JSON before crypto → treat as security failure for mutating.
  if ! python3 -c 'import json,sys; json.load(open(sys.argv[1],encoding="utf-8"))' "$tmp_man" 2>/dev/null; then
    rm -f "$tmp_man"
    if [[ "$readonly" -eq 1 ]]; then
      echo "[warn] platform manifest malformed; continuing local command" >&2
      return 0
    fi
    echo "[error] platform security: malformed release manifest" >&2
    return 1
  fi

  local remote_ver local_ver artifact_url cmp
  remote_ver="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1],encoding="utf-8")).get("version") or "")' "$tmp_man")"
  local_ver="$(soviez_version)"
  if [[ -z "$remote_ver" ]]; then
    rm -f "$tmp_man"
    if [[ "$readonly" -eq 1 ]]; then return 0; fi
    echo "[error] platform security: manifest missing version" >&2
    return 1
  fi
  if [[ "$remote_ver" == "$local_ver" ]]; then
    rm -f "$tmp_man"
    return 0
  fi

  cmp="$(soviez_platform_version_cmp "$local_ver" "$remote_ver")"
  if [[ "$cmp" == "1" ]]; then
    # Installed newer than remote — no automatic downgrade.
    rm -f "$tmp_man"
    echo "[info] platform remote $remote_ver is older than installed $local_ver; ignoring (no downgrade)" >&2
    return 0
  fi

  artifact_url="$(python3 -c 'import json,sys; m=json.load(open(sys.argv[1],encoding="utf-8")); print(m.get("artifact_url") or m.get("url") or "")' "$tmp_man")"
  if [[ -z "$artifact_url" && -z "${SOVIEZ_PLATFORM_CANDIDATE_FILE:-}" ]]; then
    rm -f "$tmp_man"
    if [[ "$readonly" -eq 1 ]]; then return 0; fi
    echo "[error] platform security: manifest missing artifact_url" >&2
    return 1
  fi

  # Read-only: best-effort notice only — do not mutate platform mid list/version.
  if [[ "$readonly" -eq 1 && "${SOVIEZ_PLATFORM_UPDATE_ON_READONLY:-0}" != "1" ]]; then
    echo "[info] newer platform available ($local_ver → $remote_ver); run a mutating command or --platform-install to update" >&2
    rm -f "$tmp_man"
    return 0
  fi

  soviez_platform_lock_acquire
  local cand
  cand="$(mktemp "${TMPDIR:-/tmp}/soviez-platform-cand.XXXXXX")"
  if [[ -n "${SOVIEZ_PLATFORM_CANDIDATE_FILE:-}" && -f "${SOVIEZ_PLATFORM_CANDIDATE_FILE}" ]]; then
    cp -f "$SOVIEZ_PLATFORM_CANDIDATE_FILE" "$cand"
  else
    if ! curl -fsSL --connect-timeout 5 --max-time 180 "$artifact_url" -o "$cand"; then
      rm -f "$cand" "$tmp_man"
      soviez_platform_lock_release
      if [[ "$require_update" -eq 1 && "${SOVIEZ_PLATFORM_UPDATE_STRICT:-0}" == "1" ]]; then
        echo "[error] platform update service unavailable (artifact download failed)" >&2
        return 1
      fi
      echo "[warn] platform candidate download failed; continuing with $local_ver" >&2
      return 0
    fi
  fi

  if ! soviez_platform_verify_candidate "$cand" "$tmp_man"; then
    rm -f "$cand" "$tmp_man"
    soviez_platform_lock_release
    # Cryptographic/trust failure — fail closed for mutating; preserve platform.
    echo "[error] platform security verification failed; candidate NOT installed; current platform preserved" >&2
    return 1
  fi

  if ! head -1 "$cand" | grep -q 'bash'; then
    rm -f "$cand" "$tmp_man"
    soviez_platform_lock_release
    echo "[error] platform security: candidate is not a bash script" >&2
    return 1
  fi

  chmod 755 "$cand"
  local install_channel
  install_channel="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1],encoding="utf-8")).get("channel") or "")' "$tmp_man")"
  install_channel="${install_channel:-$(soviez_platform_channel)}"
  SOVIEZ_PLATFORM_INSTALL_SRC="$cand" soviez_platform_install_from_file "$cand" "$install_channel" || {
    rm -f "$cand" "$tmp_man"
    soviez_platform_lock_release
    return 1
  }
  # Install bundled trust keys alongside payload when present in candidate dir packaging — keys live in share/.
  local trust_src
  trust_src="${SOVIEZ_SH_ROOT:-}/share/platform-trust"
  if [[ -d "$trust_src" ]]; then
    mkdir -p "$(soviez_platform_current_dir)/trust"
    cp -a "$trust_src/." "$(soviez_platform_current_dir)/trust/" 2>/dev/null || true
  fi

  rm -f "$cand" "$tmp_man"
  soviez_platform_lock_release

  local launcher
  launcher="$(soviez_platform_bin)"
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    launcher="${SOVIEZ_ROOT}/bin/soviez.sh"
  fi
  echo "[info] platform updated $local_ver → $remote_ver; re-executing" >&2
  exec env SOVIEZ_SKIP_PLATFORM_UPDATE=1 bash "$launcher" "$@"
}
