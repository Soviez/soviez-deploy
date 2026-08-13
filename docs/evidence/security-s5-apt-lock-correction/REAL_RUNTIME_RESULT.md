# REAL_RUNTIME_RESULT

## Environment
Disposable Ubuntu Docker guests (linux/arm64) via Colima/Docker — privileged containers for flock on `/var/lib/dpkg/lock-frontend`.

## Exercise
1. Background `flock` holder sleeps while retaining lock
2. `soviez_s5_apt_wait_for_lock` with short timeout → `PKG_LOCK_TIMEOUT`
3. Holder PID still alive (**no kill**)
4. Lock file still present (**no rm**)
5. After holder exit → `PKG_LOCK_RELEASED`

## Result
**PASS** on Ubuntu 22.04 and 24.04 guests (`test_s5_corr_apt_lock_guest.sh`).

## Limits
Not a full Production ERP provision on bare metal; proves real dpkg lock + wait-or-fail no-kill semantics on real Ubuntu userlands.
