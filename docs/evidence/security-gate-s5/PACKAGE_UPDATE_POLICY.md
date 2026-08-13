# PACKAGE_UPDATE_POLICY (evidence)

Modular `soviez-sh` policy: wait for APT locks (`soviez_s5_apt_wait_for_lock`); never `killall`/`pkill -9` apt or unattended-upgrades.

Src scan via `soviez_s5_apt_lock_healer_safe` → **SAFE**.

Legacy APT killall healer exists **ONLY** in `soviez-deploy` and must not be ported. Test: `test_s5_package_policy.sh` PASS.
