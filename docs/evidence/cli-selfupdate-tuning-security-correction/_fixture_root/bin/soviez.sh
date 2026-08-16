#!/usr/bin/env bash
# Soviez.sh stable customer launcher — do not edit.
set -euo pipefail
PAYLOAD="/Volumes/PortableSSD/soviez-project/soviez-deploy/docs/evidence/cli-selfupdate-tuning-security-correction/_fixture_root/platform/current/soviez.sh"
if [[ ! -f "$PAYLOAD" ]]; then
  echo "[error] Soviez platform payload missing: $PAYLOAD" >&2
  exit 127
fi
exec bash "$PAYLOAD" "$@"
