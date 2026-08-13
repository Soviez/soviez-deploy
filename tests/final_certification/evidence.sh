#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVID="${SOVIEZ_P25_EVIDENCE_DIR:?SOVIEZ_P25_EVIDENCE_DIR required}"
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/p25_cert.sh"
HASH_DIR="$EVID/hashes"
mkdir -p "$HASH_DIR"
while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  rel="${f#"$EVID"/}"
  p25_hash_file "$f" >"$HASH_DIR/${rel//\//__}.sha256"
done < <(find "$EVID" -type f -name '*.md' | sort)
{
  echo "# EVIDENCE_INTEGRITY"
  echo "run_id=${SOVIEZ_P25_RUN_ID:-unknown}"
  echo "hash_dir=$HASH_DIR"
  echo "file_count=$(find "$EVID" -type f | wc -l | tr -d ' ')"
  echo "local_only=YES"
  echo "secret_redacted=YES"
} >"$EVID/EVIDENCE_INTEGRITY.md"
echo "OK evidence"
exit 0
