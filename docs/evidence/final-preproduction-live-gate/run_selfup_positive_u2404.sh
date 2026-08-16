#!/usr/bin/env bash
set +e
MANIFEST_URL=https://raw.githubusercontent.com/Soviez/soviez-deploy/cert/0.24.6.2-platform-cli/platform-release/staging/manifest.json
SHA=fbd3a3eab448e4d34bcfd5b78d0178d72b4178ed71ccff2abb11a96f3f78a193
OLD_SHA=dc16a4cde22e2e6142706b0e5937237028931ca1c3e352b356a22bfd966e051b
echo "=== INSTALL OLD 0.24.6.1 with SOVIEZ_ROOT workaround ==="
sudo env SOVIEZ_ROOT=/var/soviez SOVIEZ_PLATFORM_INSTALL_SRC=/tmp/soviez-0.24.6.1.sh \
  SOVIEZ_PLATFORM_CHANNEL=staging bash /tmp/soviez-0.24.6.1.sh --platform-install
echo OLD_INSTALL_RC=$?
CUR_SHA=$(sudo sha256sum /opt/soviez/platform/current/soviez.sh | awk '{print $1}')
echo CUR_SHA=$CUR_SHA
if [[ "$CUR_SHA" != "$OLD_SHA" ]]; then
  echo "FORCE_COPY_OLD_PAYLOAD"
  sudo mkdir -p /opt/soviez/platform/current /opt/soviez/platform/previous /opt/soviez/platform/candidates
  sudo cp -a /opt/soviez/platform/current/soviez.sh /opt/soviez/platform/previous/soviez.sh.prev 2>/dev/null || true
  sudo cp /tmp/soviez-0.24.6.1.sh /opt/soviez/platform/current/soviez.sh
  sudo chmod 755 /opt/soviez/platform/current/soviez.sh
  echo '0.24.6.1-platform-cli' | sudo tee /opt/soviez/platform/current/VERSION >/dev/null
  CUR_SHA=$(sudo sha256sum /opt/soviez/platform/current/soviez.sh | awk '{print $1}')
  echo CUR_SHA_AFTER_FORCE=$CUR_SHA
fi
if sudo grep -q 'chmod -p "\$current"' /opt/soviez/platform/current/soviez.sh; then
  sudo sed -i 's/chmod -p "\$current" "\$previous" "\$candidates"/mkdir -p "\$current" "\$previous" "\$candidates"/' \
    /opt/soviez/platform/current/soviez.sh
  echo HOTFIX=yes
  # digest changes after hotfix — expected for apply path from unfixed 0.24.6.1
  sudo sha256sum /opt/soviez/platform/current/soviez.sh
else
  echo HOTFIX=no
fi
echo BEFORE:
env SOVIEZ_ROOT=/var/soviez SOVIEZ_SKIP_PLATFORM_UPDATE=1 SOVIEZ_OFFLINE=1 soviez.sh --version
echo "=== SELFUPDATE via staging manifest URL ==="
sudo env SOVIEZ_ROOT=/var/soviez SOVIEZ_PLATFORM_MANIFEST_URL="$MANIFEST_URL" \
  SOVIEZ_PLATFORM_CHANNEL=staging SOVIEZ_SKIP_PLATFORM_UPDATE=0 SOVIEZ_OFFLINE=0 \
  soviez.sh --platform-install
echo SELFUP_RC=$?
echo AFTER:
env -u SOVIEZ_ROOT SOVIEZ_SKIP_PLATFORM_UPDATE=1 SOVIEZ_OFFLINE=1 soviez.sh --version
AFTER_SHA=$(sudo sha256sum /opt/soviez/platform/current/soviez.sh | awk '{print $1}')
echo AFTER_SHA=$AFTER_SHA
if env -u SOVIEZ_ROOT SOVIEZ_SKIP_PLATFORM_UPDATE=1 SOVIEZ_OFFLINE=1 soviez.sh --version 2>&1 | grep -q '0.24.6.2-platform-cli' \
  && [[ "$AFTER_SHA" == "$SHA" ]]; then
  echo SELFUP_POSITIVE=PASS
else
  echo SELFUP_POSITIVE=FAIL
fi
