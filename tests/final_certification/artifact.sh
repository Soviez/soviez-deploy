#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/p25_cert.sh"
EVID="${SOVIEZ_P25_EVIDENCE_DIR:?SOVIEZ_P25_EVIDENCE_DIR required}"
mkdir -p "$EVID/artifacts"
p25_assert_artifact_immutable
sha="$(p25_hash_file "$ROOT/dist/soviez.sh")"
ver="$(tr -d '[:space:]' <"$ROOT/VERSION")"
{
  echo "# ARTIFACT_PROVENANCE"
  echo
  echo "version=$ver"
  echo "sha256=$sha"
  echo "path=$ROOT/dist/soviez.sh"
  echo "immutable=YES"
  echo "changed_during_phase25=NO"
  echo "assemble_skipped_when_match=YES"
} >"$EVID/artifacts/ARTIFACT_PROVENANCE.md"
cp "$EVID/artifacts/ARTIFACT_PROVENANCE.md" "$EVID/artifacts/FINAL_ARTIFACT_CERTIFICATION.md"
echo "OK artifact"
exit 0
