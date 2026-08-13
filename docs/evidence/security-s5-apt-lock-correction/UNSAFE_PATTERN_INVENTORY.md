# UNSAFE_PATTERN_INVENTORY

Patterns banned on supported Production installers after S5 corr1.

| Pattern | Why unsafe | Status on supported paths |
|---------|------------|---------------------------|
| `killall -9 apt apt-get dpkg unattended-upgrade` | Aborts mid-transaction; can corrupt dpkg state | **REMOVED** from ERP + deploy; absent as executable line in `dist/soviez.sh` |
| Blind `rm -f` of `/var/lib/dpkg/lock*`, `/var/lib/apt/lists/lock`, `/var/cache/apt/archives/lock` inside `heal_apt_locks` | Allows concurrent writers; race/corruption | **REMOVED** |
| `pkill -9` / `kill -9` targeting package managers to “heal” locks | Same class as killall | **Not present** in supported heal paths |
| Force-continue past `PKG_LOCK_TIMEOUT` | Defeats fail-closed safety | **Forbidden** — timeout aborts op |

## Detector / assertion surfaces
- `soviez_pkg_assert_installer_no_kill`
- `soviez_sec_legacy_assert_apt_lock_safe` (`legacy_bridge.sh`)
- `soviez_s5_apt_lock_healer_safe` (`package_policy.sh`)
- CORR-APT-005/006 static checks

## Historical (not supported Production)
`review-candidates/*/soviez.sh` still shows pre-corr kill+rm healers — classified obsolete reference only; not remediated as Production.
