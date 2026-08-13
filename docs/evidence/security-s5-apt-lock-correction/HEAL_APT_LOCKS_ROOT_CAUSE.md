# HEAL_APT_LOCKS_ROOT_CAUSE

## Defect
Pre-corr dual Production wizard `heal_apt_locks` treated a held APT/DPKG lock as a stuck condition to **force-clear**:
1. `killall -9 apt apt-get dpkg unattended-upgrade`
2. `rm -f` of standard apt/dpkg lock files

## Why it appeared “necessary”
Install/certbot/host init paths called `heal_apt_locks` before `apt-get` so unattended-upgrades or concurrent apt would not block the wizard. Kill+rm was a short-cut for disposable lab hosts that became unacceptable on Production.

## Why it is unsafe
- Mid-dpkg kill leaves half-configured packages (`PKG_STATE_INCONSISTENT` class).
- Removing lock files does not stop a live holder; next writer races.
- Unattended-upgrades is a legitimate security-patch owner — killing it defeats host patch posture.

## Gap vs modular S5
Gate S5 already shipped wait-only `soviez_s5_apt_wait_for_lock` in `soviez-sh`, but Case A dual wizard (ERP ↔ deploy) retained the kill healer. Corr1 closes that ownership gap.

## Fix principle
Retain function name `heal_apt_locks` for call-site compatibility; change behavior to **wait-or-fail** (prefer bridging to canonical `soviez_s5_apt_wait_for_lock` when sourced).
