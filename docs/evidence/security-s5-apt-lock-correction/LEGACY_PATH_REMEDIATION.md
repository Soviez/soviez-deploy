# LEGACY_PATH_REMEDIATION

## Case A action completed
Both supported Production wizards remediated in lockstep:

| Path | Remediation |
|------|-------------|
| `Soviez ERP/soviez.sh` | `heal_apt_locks` → wait-or-fail; optional bridge to `soviez_s5_apt_wait_for_lock` |
| `soviez-deploy/soviez.sh` | Same content (byte-identical to ERP) |
| `soviez-sh/dist/soviez.sh` | Assembled with `apt_lock.sh` + package_policy SAFE scan |

## Call-site compatibility
Function name `heal_apt_locks` retained so existing call sites keep working without behavioral kill.

## Assertions
- `soviez_pkg_assert_installer_no_kill` on ERP + deploy
- `soviez_sec_legacy_assert_apt_lock_safe` on ERP + deploy
- CORR-APT-005/006

## Not remediated (by design)
`review-candidates/**` historical snapshots — obsolete reference, not Production download path.
