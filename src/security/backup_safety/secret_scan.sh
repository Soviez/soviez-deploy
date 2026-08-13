# shellcheck shell=bash
# Security Gate S5 — backup secret leakage scan (REQUIRED vs UNNECESSARY).

soviez_s5_backup_secret_scan() {
  local dir="$1"
  if [[ -z "$dir" || ! -d "$dir" ]]; then
    echo FAIL
    return 1
  fi

  local required=0 unnecessary=0
  local findings="$dir/.s5_secret_scan.jsonl"
  : >"$findings"

  # REQUIRED leaks: secrets that must exist for restore (e.g. encrypted key sidecars under policy).
  # UNNECESSARY leaks: private keys, docker auth.json, plaintext credentials that should not ship.

  local f
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    local base
    base="$(basename "$f")"
    case "$base" in
      auth.json|config.json)
        if grep -Eqi '"auth"|auths|identitytoken|registrytoken' "$f" 2>/dev/null; then
          echo "{\"path\":\"$f\",\"class\":\"UNNECESSARY\",\"kind\":\"docker_auth\"}" >>"$findings"
          unnecessary=1
        fi
        ;;
      id_rsa|id_ecdsa|id_ed25519|*.pem|*.key)
        # Private keys in backup trees are unnecessary unless explicitly allowlisted.
        if [[ "${SOVIEZ_S5_BACKUP_ALLOW_PRIVATE_KEYS:-0}" == "1" ]]; then
          echo "{\"path\":\"$f\",\"class\":\"REQUIRED\",\"kind\":\"private_key_allowlisted\"}" >>"$findings"
          required=1
        else
          echo "{\"path\":\"$f\",\"class\":\"UNNECESSARY\",\"kind\":\"private_key\"}" >>"$findings"
          unnecessary=1
        fi
        ;;
      *.enc|encryption.key.meta|backup.key.meta)
        echo "{\"path\":\"$f\",\"class\":\"REQUIRED\",\"kind\":\"encryption_meta\"}" >>"$findings"
        required=1
        ;;
    esac
    # Content heuristics
    if grep -Eqi 'BEGIN[[:space:]]+(RSA |OPENSSH |EC )?PRIVATE KEY' "$f" 2>/dev/null; then
      if [[ "${SOVIEZ_S5_BACKUP_ALLOW_PRIVATE_KEYS:-0}" != "1" ]]; then
        echo "{\"path\":\"$f\",\"class\":\"UNNECESSARY\",\"kind\":\"pem_private_key\"}" >>"$findings"
        unnecessary=1
      fi
    fi
    if grep -Eqi 'postgres(ql)?://[^:]+:[^@]+@|PASSWORD=|ADMIN_PASSWD=' "$f" 2>/dev/null \
      && [[ "$f" != *.enc ]]; then
      echo "{\"path\":\"$f\",\"class\":\"UNNECESSARY\",\"kind\":\"plaintext_credential\"}" >>"$findings"
      unnecessary=1
    fi
  done < <(find "$dir" -type f ! -name '.s5_secret_scan.jsonl' 2>/dev/null | head -n 5000)

  if [[ "$unnecessary" -eq 1 ]]; then
    echo UNNECESSARY
    return 1
  fi
  if [[ "$required" -eq 1 ]]; then
    echo REQUIRED
    return 0
  fi
  echo PASS
  return 0
}
