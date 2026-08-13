# CHANGED_FILES

Primary S5 surfaces (modular `soviez-sh`):

- `src/security/update_safety/*` — baseline, network, DNS, outbound, package_policy, pdf, reboot, restart, rollback, gate, report
- `src/security/backup_safety/*` — posture, integrity, encryption, retention, disk, restore_verify, secret_scan, gate, report
- `src/security/codes.sh` — S5 security codes (incl. `SEC_HIGH_BACKUP_LOCAL_ONLY`)
- `src/update/engine.sh` — S5 enforce hooks (`SOVIEZ_S5_ENFORCE=1` or non-test Production path)
- `tests/security/run_security_gate_s5.sh`
- `tests/security/update_safety/test_s5_*.sh`
- `tests/security/backup_safety/test_s5_*.sh`
- `docs/evidence/security-gate-s5/*`, `docs/security/*` S5 policy docs
- Assembled `dist/soviez.sh` → `0.24.5-security-s5`

Not ported: legacy APT `killall` healer from `soviez-deploy` (modular path is wait-only `soviez_s5_apt_wait_for_lock`).
