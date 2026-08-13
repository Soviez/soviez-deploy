# STATIC_UNSAFE_PATTERN_SCAN

## Targets
- `soviez-sh/dist/soviez.sh`
- `Soviez ERP/soviez.sh`
- `soviez-deploy/soviez.sh`
- Modular `src/security/**` (healer SAFE scan excludes detector strings in `apt_lock.sh` itself)

## Checks
| Check | Result |
|-------|--------|
| Executable `killall -9` apt/dpkg/unattended on supported installers | ABSENT |
| Blind lock `rm` inside `heal_apt_locks` | ABSENT |
| `soviez_s5_apt_lock_healer_safe` | SAFE |
| `soviez_pkg_assert_installer_no_kill` ERP/deploy | SAFE |
| `soviez_sec_legacy_assert_apt_lock_safe` ERP/deploy | SAFE |

## Result
**PASS** (CORR-APT-005/006)
