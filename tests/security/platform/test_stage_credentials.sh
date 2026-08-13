#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
echo "TEST-SEC stage credentials source hygiene"
for f in \
  "$ROOT/src/migration/staging/startup.sh" \
  "$ROOT/src/update/real_docker.sh" \
  "$ROOT/src/backup/restore_test.sh"
do
  if grep -E -q 'POSTGRES_PASSWORD=odoo([[:space:]]|$)|POSTGRES_USER=odoo([[:space:]]|$)' "$f"; then
    echo "FAIL weak default still in $f"; exit 1
  fi
  if ! grep -q 'secrets.choice\|soviez_sec_pg_gen_password\|python3 -c.*secrets' "$f"; then
    echo "FAIL no random generator in $f"; exit 1
  fi
done
echo "PASS stage credentials"
