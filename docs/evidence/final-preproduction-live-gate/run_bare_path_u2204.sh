#!/usr/bin/env bash
set +e
echo "=== u2204 install 0.24.6.2 ==="
sudo mkdir -p /var/soviez /opt/soviez/platform
sudo env SOVIEZ_PLATFORM_INSTALL_SRC=/tmp/soviez-0.24.6.2.sh SOVIEZ_PLATFORM_CHANNEL=staging \
  bash /tmp/soviez-0.24.6.2.sh --platform-install
echo INSTALL_RC=$?
sudo sha256sum /opt/soviez/platform/current/soviez.sh
cd /tmp
unset SOVIEZ_ROOT
export SOVIEZ_SKIP_PLATFORM_UPDATE=1 SOVIEZ_OFFLINE=1
echo "=== bare PATH ==="
env -u SOVIEZ_ROOT soviez.sh --version
echo RC_VERSION=$?
env -u SOVIEZ_ROOT soviez.sh --list | head -3
echo RC_LIST=$?
env -u SOVIEZ_ROOT soviez.sh --stage-list | head -2
echo RC_STAGE=$?
printf '%s\n' '[options]' 'proxy_mode = True' 'workers = 0' 'list_db = False' >/tmp/odoo-gate.conf
env -u SOVIEZ_ROOT SOVIEZ_SIZING_FORCE_CPU=4 SOVIEZ_SIZING_FORCE_RAM_MB=8192 SOVIEZ_TUNE_ODOO_CONF=/tmp/odoo-gate.conf \
  soviez.sh --tune --dry-run >/tmp/tune.out 2>&1
echo RC_TUNE=$?
head -5 /tmp/tune.out
grep -qi '0.24.6.2-platform-cli' <<<"$(env -u SOVIEZ_ROOT soviez.sh --version 2>&1)" && echo BARE_VER=PASS || echo BARE_VER=FAIL
grep -qi 'TYPE' <<<"$(env -u SOVIEZ_ROOT soviez.sh --list 2>&1)" && echo BARE_LIST=PASS || echo BARE_LIST=FAIL
grep -qi 'Stage' <<<"$(env -u SOVIEZ_ROOT soviez.sh --stage-list 2>&1)" && echo BARE_STAGE=PASS || echo BARE_STAGE=FAIL
grep -qi 'sizing\|workers\|dry' /tmp/tune.out && echo BARE_TUNE=PASS || echo BARE_TUNE=FAIL
