# IDEMPOTENCY

## Wait API
Repeated `soviez_s5_apt_wait_for_lock` when unlocked → stable `PKG_LOCK_RELEASED` (CORR-APT-007).

## Assert API
Repeated `soviez_pkg_assert_installer_no_kill` on the same installer path → stable SAFE.

## Dual wizard
Re-entering `heal_apt_locks` when unlocked is a no-op success; when locked, same wait-or-fail semantics each call.

## Result
**PASS**
