#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
EXP=68ab59972d84d34f38c43862ca28946d3df3da5707fefa970230bd43e1da3460
sha=$(shasum -a 256 dist/soviez.sh | awk '{print $1}')
[[ "$sha" == "$EXP" ]] || { echo "FAIL artifact SHA"; exit 1; }
[[ -f docs/README.md && -f docs/user/CLI_REFERENCE.md && -f docs/user/WEBSOCKET_AND_LONGPOLLING.md ]]
[[ -f docs/dev/SECURITY_ARCHITECTURE.md && -f docs/ai/CURRENT_STATE.md ]]
[[ -f docs/evidence/documentation-canonicalization/WEBSOCKET_LONGPOLLING_SOURCE_AUDIT.md ]]
rg -q 'NEVER installs Webmin' docs/security/WEBMIN_VIRTUALMIN.md docs/user/SECURITY.md
rg -q 'NOT_SUPPORTED' docs/DOCUMENTATION_COVERAGE_MATRIX.md
rg -q 'LOCAL_ONLY' docs/user/BACKUP.md
echo "OK docs_validate"
