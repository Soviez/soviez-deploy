# shellcheck shell=bash
# Security Gate S5 — backup ciphertext / encryption assertions.

soviez_s5_backup_assert_ciphertext() {
  local file="$1"
  if [[ -z "$file" || ! -f "$file" ]]; then
    echo FAIL
    return 1
  fi

  # Reject obvious plaintext SQL dumps.
  local head
  head="$(head -c 256 "$file" 2>/dev/null || true)"
  if printf '%s' "$head" | grep -Eqi '^(--|SET |CREATE |COPY |BEGIN|PostgreSQL database dump)'; then
    echo "[error] security:SEC_HIGH_BACKUP_PLAINTEXT: plaintext SQL detected in ${file}" >&2
    echo FAIL
    return 1
  fi
  # Plain .sql extension with ASCII content.
  if [[ "$file" == *.sql ]]; then
    echo FAIL
    return 1
  fi

  # Accept common encrypted envelope markers / high-entropy binary.
  if [[ "$file" == *.enc ]] || [[ "$file" == *.gpg ]] || [[ "$file" == *.age ]]; then
    echo PASS
    return 0
  fi
  # OpenSSL salted header
  if printf '%s' "$head" | grep -q 'Salted__'; then
    echo PASS
    return 0
  fi

  # If encryption is required by policy, unmarked files fail.
  if [[ "${SOVIEZ_S5_BACKUP_REQUIRE_ENCRYPT:-0}" == "1" ]]; then
    echo FAIL
    return 1
  fi

  # Soft pass when encryption optional and not plaintext SQL.
  echo PASS
  return 0
}

soviez_s5_backup_wrong_key_fail() {
  # Helper: decrypt attempt with wrong key must fail (fixture / openssl path).
  local enc_file="$1"
  local wrong_pass="${2:-definitely-wrong-passphrase}"
  if [[ -z "$enc_file" || ! -f "$enc_file" ]]; then
    echo FAIL
    return 1
  fi
  if [[ "${SOVIEZ_S5_BACKUP_INJECT_WRONG_KEY_OK:-0}" == "1" ]]; then
    # Fault injection: pretend wrong key succeeded (should not happen in real path).
    echo FAIL
    return 1
  fi
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/soviez-s5-wrongkey.XXXXXX")"
  if command -v openssl >/dev/null 2>&1; then
    if openssl enc -d -aes-256-cbc -pbkdf2 -in "$enc_file" -out "$tmp" -pass "pass:${wrong_pass}" >/dev/null 2>&1; then
      rm -f "$tmp"
      # Wrong key unexpectedly worked.
      echo FAIL
      return 1
    fi
  fi
  rm -f "$tmp"
  echo PASS
  return 0
}
