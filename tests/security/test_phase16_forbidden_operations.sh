#!/usr/bin/env bash
# Phase 16 — forbidden broad/insecure operations static gate.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail=0
scan() {
  local pat="$1"
  # Ignore comment-only mentions; match real option/command usage.
  if grep -REn --include='*.sh' "$pat" "$ROOT/src/backup" "$ROOT/src/restore" 2>/dev/null \
    | grep -v '^\s*#' | grep -v ':[[:space:]]*#' >/dev/null; then
    grep -REn --include='*.sh' "$pat" "$ROOT/src/backup" "$ROOT/src/restore" 2>/dev/null \
      | grep -v '^\s*#' | grep -v ':[[:space:]]*#' || true
    echo "FORBIDDEN pattern found: $pat" >&2
    fail=1
  fi
}

scan 'aws s3 rm --recursive'
scan 'mc rm --recursive'
scan 'rclone purge'
scan 'StrictHostKeyChecking=no'
scan 'docker system prune'
scan 'docker volume prune'
scan 'docker image prune -a'
# Broad unverified rm -rf of variables that look like remote roots (heuristic)
if grep -REn --include='*.sh' 'rm -rf \$\{?(UNVERIFIED|REMOTE|BUCKET|S3_|SFTP_).*' "$ROOT/src/backup" "$ROOT/src/restore" 2>/dev/null; then
  echo "FORBIDDEN unverified rm -rf pattern" >&2
  fail=1
fi

# Assembled artifact must also be clean
bash "$ROOT/build/assemble.sh" >/dev/null
for pat in 'aws s3 rm --recursive' 'mc rm --recursive' 'rclone purge' 'StrictHostKeyChecking=no' \
           'docker system prune' 'docker volume prune' 'docker image prune -a'; do
  if grep -F "$pat" "$ROOT/dist/soviez.sh" | grep -v '^[[:space:]]*#' | grep -v '#.*'"$pat" >/dev/null; then
    # Dist is concatenated; filter comment lines containing the pattern
    if grep -nF "$pat" "$ROOT/dist/soviez.sh" | grep -v ':[[:space:]]*#' | grep -v 'Never ' >/dev/null; then
      echo "FORBIDDEN in dist: $pat" >&2
      fail=1
    fi
  fi
done

# Positive: exact delete helpers exist
grep -q 'soviez_backup_s3_dest_delete_exact' "$ROOT/dist/soviez.sh"
grep -q 'soviez_backup_sftp_dest_delete_exact' "$ROOT/dist/soviez.sh"
grep -q 'StrictHostKeyChecking=yes' "$ROOT/dist/soviez.sh"

[[ $fail -eq 0 ]] || exit 1
echo "PASS test_phase16_forbidden_operations"
