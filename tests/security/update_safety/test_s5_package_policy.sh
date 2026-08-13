#!/usr/bin/env bash
# S5 package / unattended-upgrades / rollback policy unit checks.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
unset SOVIEZ_SH_ROOT
BAK=""
if [[ -f "$ROOT/dist/soviez.sh" ]] && ! grep -q 'soviez_s5_unattended_upgrades_status' "$ROOT/dist/soviez.sh" 2>/dev/null; then
  BAK="$ROOT/dist/soviez.sh.s5bak.$$"
  mv "$ROOT/dist/soviez.sh" "$BAK"
fi
source "$ROOT/tests/helpers/s1_platform.sh"
s5_platform_source
export SOVIEZ_SH_ROOT="$ROOT"
export SOVIEZ_TEST_MODE=1
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
trap '
  if [[ -n "${BAK:-}" && -f "$BAK" ]]; then mv "$BAK" "$ROOT/dist/soviez.sh"; fi
' EXIT

ua="$(soviez_s5_unattended_upgrades_status)"
[[ -n "$ua" ]]
echo "OK unattended status=$ua"

apt_safe="$(soviez_s5_apt_lock_healer_safe)"
[[ "$apt_safe" == "SAFE" ]]
echo "OK apt_lock_healer_safe=SAFE"

disrupt="$(soviez_s5_docker_package_update_is_disruptive)"
[[ "$disrupt" == "true" ]]
echo "OK docker_package_disruptive=true"

reboot="$(soviez_s5_detect_reboot_required)"
[[ "$reboot" == "REQUIRED" || "$reboot" == "NOT_REQUIRED" ]]
svc="$(soviez_s5_detect_service_restart_required)"
[[ -n "$svc" ]]
svc2="$(SOVIEZ_S5_INJECT_NEEDRESTART=REQUIRED soviez_s5_detect_service_restart_required)"
[[ "$svc2" == "REQUIRED" ]]
echo "OK reboot/service detection reboot=$reboot svc=$svc"

plan="$(mktemp "${TMPDIR:-/tmp}/soviez-s5-rb.XXXXXX")"
cat >"$plan" <<'EOF'
# Rollback plan — NEVER restore SUPERUSER or 0.0.0.0:8069
# assert not insecure
EOF
rb="$(soviez_s5_assert_rollback_not_insecure "$plan")"
[[ "$rb" == "PASS" ]]
bad="$(mktemp "${TMPDIR:-/tmp}/soviez-s5-rb-bad.XXXXXX")"
echo "GRANT SUPERUSER TO odoo; publish 0.0.0.0:8069" >"$bad"
set +e
bad_out="$(soviez_s5_assert_rollback_not_insecure "$bad" 2>/dev/null)"
bad_rc=$?
set -e
[[ "$bad_out" == "FAIL" ]]
[[ "$bad_rc" -ne 0 ]]
rm -f "$plan" "$bad"
echo "OK rollback_not_insecure"

echo PASS
