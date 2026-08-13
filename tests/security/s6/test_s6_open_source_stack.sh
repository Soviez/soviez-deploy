#!/usr/bin/env bash
# S6 — open-source stack posture: mandatory / optional / deferred (from codebase policy).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/tests/helpers/s1_platform.sh"
s6_platform_source
# shellcheck disable=SC1091
source "$ROOT/tests/helpers/s6_cert.sh"
export SOVIEZ_TEST_MODE=1
export SOVIEZ_SH_ROOT="$ROOT"
export SOVIEZ_SEC_S6_EVIDENCE_ROOT="${SOVIEZ_SEC_S6_EVIDENCE_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/soviez-s6-oss.XXXXXX")}"
ev="$(s6_evidence_init "$(s6_run_id)")"
trap '[[ "${SOVIEZ_S6_KEEP_EVIDENCE:-0}" == "1" ]] || rm -rf "$SOVIEZ_SEC_S6_EVIDENCE_ROOT"' EXIT

fail=0
DOC="$ev/audit/OPEN_SOURCE_STACK.md"
{
  echo "# S6 Open Source Stack Posture"
  echo ""
  echo "| Tool | Classification | Source |"
  echo "|------|----------------|--------|"
  echo "| Fail2Ban | MANDATORY_PREFERRED (S2 brute-force; install deferred if absent) | src/security/platform/brute_force.sh |"
  echo "| Firewall (ufw/firewalld/nftables) | MANDATORY_POLICY (backend detected; stage may SKIP on macOS) | src/security/platform/firewall*.sh |"
  echo "| YARA | OPTIONAL_TARGETED (offline curated; fallback OK) | src/security/detection/yara_scan.sh |"
  echo "| AIDE | DEFERRED (native fingerprints instead) | src/security/detection/host_integrity.sh |"
  echo "| ClamAV | DEFERRED_ON_DEMAND_NOT_DEFAULT | src/security/detection/tooling_policy.sh |"
  echo "| Wazuh | REJECTED_NO_SERVER_INFRA | tooling_policy.sh |"
  echo "| CrowdSec | OPTIONAL_S2_OD (does not replace Fail2Ban) | brute_force.sh |"
  echo "| auditd | NARROW_OPTIONAL | tooling_policy.sh |"
  echo "| Lynis | SUPPORTING_ONLY_ON_DEMAND | tooling_policy.sh |"
} >"$DOC"

# Assert tooling_policy JSON classifications
pol="$(soviez_s3_optional_tools_status)"
echo "$pol" | grep -q 'DEFERRED_ON_DEMAND_NOT_DEFAULT' || { echo "FAIL clamav policy" >&2; fail=1; }
echo "$pol" | grep -q 'REJECTED_NO_SERVER_INFRA' || { echo "FAIL wazuh policy" >&2; fail=1; }
echo "$pol" | grep -q 'DEFERRED_NATIVE_FINGERPRINTS' || { echo "FAIL aide policy" >&2; fail=1; }
echo "$pol" | grep -q 'TARGETED_OFFLINE_CURATED' || { echo "FAIL yara policy" >&2; fail=1; }

# No default ClamAV/Wazuh install paths in Production security modules
if grep -RInE --include='*.sh' \
  -e 'apt-get install -y clamav|yum install .*clamav|apt-get install -y wazuh|wazuh-agent' \
  "$ROOT/src/security" 2>/dev/null \
  | grep -vE 'DEFERRED|NOT_DEFAULT|REJECTED|optional|comment|#' >/dev/null 2>&1; then
  # Allow only if clearly gated; still flag hard default installers
  if grep -RInE --include='*.sh' \
    -e '^[[:space:]]*apt-get install -y clamav|^[[:space:]]*apt-get install -y wazuh' \
    "$ROOT/src/security" 2>/dev/null; then
    echo "FAIL default ClamAV/Wazuh install present" >&2
    fail=1
  fi
fi

# Fail2Ban preferred path exists
grep -q 'fail2ban' "$ROOT/src/security/platform/brute_force.sh" || { echo "FAIL Fail2Ban path missing" >&2; fail=1; }
# AIDE deferred comment / native fingerprints
grep -q 'AIDE deferred' "$ROOT/src/security/detection/host_integrity.sh" \
  || grep -qi 'aide' "$ROOT/src/security/detection/tooling_policy.sh" \
  || { echo "FAIL AIDE deferred not documented" >&2; fail=1; }

[[ "$(soviez_s3_lynis_decision)" == "SUPPORTING_ONLY_ON_DEMAND" ]] || fail=1

s6_write_json "$ev/findings/open_source_stack.json" "$(cat <<EOF
{
  "status": "$([[ $fail -eq 0 ]] && echo PASS || echo FAIL)",
  "fail2ban": "MANDATORY_PREFERRED",
  "firewall": "MANDATORY_POLICY",
  "yara": "OPTIONAL_TARGETED",
  "aide": "DEFERRED",
  "clamav": "DEFERRED_ON_DEMAND_NOT_DEFAULT",
  "wazuh": "REJECTED_NO_SERVER_INFRA",
  "doc": "audit/OPEN_SOURCE_STACK.md"
}
EOF
)"

[[ $fail -eq 0 ]] || { echo "FAIL open source stack" >&2; exit 1; }
echo "OK open source stack posture → $DOC"
echo PASS
