# FIREWALL_RELOAD_SAFETY

Ubuntu **22.04** and **24.04** disposable guests: firewall reload survival → **PASS** (`test_s5_firewall_reboot_guest.sh`).

Reload must not silently drop S5-relevant allow/deny posture; post-check uses baseline digest comparison.
