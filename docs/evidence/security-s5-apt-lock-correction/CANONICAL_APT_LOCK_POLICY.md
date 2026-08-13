# CANONICAL_APT_LOCK_POLICY

## Source of truth
`soviez-sh/src/security/update_safety/apt_lock.sh`

## Primary API
`soviez_s5_apt_wait_for_lock [timeout_secs]`
- Alias: `soviez_pkg_wait_for_apt_lock`
- Default timeout: `SOVIEZ_APT_LOCK_TIMEOUT` or `SOVIEZ_S5_APT_LOCK_TIMEOUT` or **120**

## Behavior
1. Detect holders via fuser/lsof on lock files + pgrep for apt/apt-get/dpkg/unattended-upgrade
2. Report owners (cmdline redacted for password/token/secret/key)
3. Wait bounded interval; emit progress every 15s
4. Success → `PKG_LOCK_RELEASED` (exit 0)
5. Persist → `PKG_LOCK_TIMEOUT` (exit 1); **no kill**, **no lock delete**
6. Soft inconsistency without lock → `PKG_STATE_INCONSISTENT` (informational; exit 0)

## Hard bans
- Never kill apt / apt-get / dpkg / unattended-upgrades
- Never `rm` apt/dpkg lock files to unblock
- Never treat timeout as soft continue on Production package mutation paths

## Dual wizard
`heal_apt_locks` implements the same policy locally and bridges to the canonical function when available.
