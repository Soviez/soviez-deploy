# NO_KILL_PROOF

## Claim
Supported Production APT lock handling never sends SIGKILL to apt/dpkg/unattended-upgrades and never deletes lock files to unblock.

## Proof method
1. **Static:** grep/assert no executable `killall -9 … apt|dpkg|unattended` and no blind lock `rm` inside `heal_apt_locks` on ERP, deploy, and modular dist.
2. **Dynamic guest:** hold `/var/lib/dpkg/lock-frontend` with `flock`; run wait with timeout; assert holder PID still `kill -0`-able; assert lock path still exists; then release and re-wait → RELEASED.

## Suites
- `tests/security/update_safety/test_s5_corr_apt_lock.sh` (CORR-APT-001…008)
- `tests/security/update_safety/test_s5_corr_apt_lock_guest.sh` (22.04 + 24.04)

## Result
**PASS**
