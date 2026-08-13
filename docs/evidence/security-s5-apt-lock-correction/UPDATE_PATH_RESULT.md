# UPDATE_PATH_RESULT

## Modular (`soviez-sh`)
Update preflight waits for APT locks via `soviez_s5_apt_wait_for_lock`. Timeout → `UPDATE_PREFLIGHT_BLOCKED` without killing package managers.

## Dual wizard
Paths that invoke apt (run_cmd apt-get wrappers, certbot plugin ensure) call `heal_apt_locks` which is wait-or-fail after corr1.

## Result
**PASS** — update path uses wait-or-fail; no kill/rm healer on supported Production update entrypoints.

## Notes
Full live Production update against customer data was not authorized; certification is unit + guest lock proofs + static path wiring.
