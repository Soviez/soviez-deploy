# OPERATION_ENGINE_INTEGRATION

## Modular update engine
`src/update/engine.sh` → `soviez_update_run` preflight:
- Calls `soviez_s5_apt_wait_for_lock` unless `SOVIEZ_S5_SKIP_APT_LOCK=1`
- Enforced when not test mode, or when `SOVIEZ_S5_ENFORCE_APT_LOCK=1`
- On `PKG_LOCK_TIMEOUT` → `UPDATE_PREFLIGHT_BLOCKED` / Needs Action (no kill)

## Broader S5 hooks
Existing S5 enforce flag `SOVIEZ_S5_ENFORCE=1` (baseline/semantic validation) remains; corr1 adds dedicated APT lock preflight independent of full matrix.

## Platform package installs
Example: Fail2Ban install path in `brute_force.sh` waits via `soviez_s5_apt_wait_for_lock` and fails closed on timeout.

## Dual wizard
`heal_apt_locks` remains the call-site name before apt-get / certbot / host init; behavior is wait-or-fail with optional bridge to canonical modular wait.
