# GIT_DIFF_SUMMARY

## Tree state
Uncommitted local work for S5 Corrective Closure (corr1). Repository may show no commits yet / dirty working tree. **No commit authorized.** No push/deploy/publish.

## Primary surfaces (corr1)
- `soviez-sh/src/security/update_safety/apt_lock.sh` (canonical wait-or-fail)
- `soviez-sh/src/security/update_safety/package_policy.sh` / `legacy_bridge.sh` asserts
- `soviez-sh/src/update/engine.sh` APT preflight
- `soviez-sh/dist/soviez.sh` assembled `0.24.5.1-security-s5-corr1`
- Dual wizard: `Soviez ERP/soviez.sh`, `soviez-deploy/soviez.sh` (`heal_apt_locks` wait-or-fail)
- Tests: `run_s5_corr_apt_lock.sh`, `test_s5_corr_apt_lock*.sh`
- Docs: `docs/evidence/security-s5-apt-lock-correction/*`, security policy notes, PROJECT_STATE / ai state (D125)

## Explicit
Do not treat this summary as a git commit. Owner must authorize any future commit separately.
