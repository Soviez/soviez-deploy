# Update Safety (Security Gate S5 + S6 certification)

Pre-change baseline → controlled mutation → post semantic validation. PASS requires protected network/firewall/port posture and required connectivity checks — not “containers Up”.

- APT: wait/backoff only (`soviez_s5_apt_wait_for_lock`); never kill apt/dpkg/unattended-upgrades; never blind-rm locks.
- Engine hooks S5 when `SOVIEZ_S5_ENFORCE=1` or non-test Production path; corr1 APT preflight in `soviez_update_run` (unless `SOVIEZ_S5_SKIP_APT_LOCK=1`).
- Offline/quarantine modes adjust outbound expectations.
- Real PDF path certified in S6 via Production Odoo image wkhtmltopdf (inject FAIL blocks).

## S5 Corrective Closure (corr1)
Package-lock safety closed for Case A dual wizard + modular dist (`0.24.5.1-security-s5-corr1`, SHA256 `78092b384b28dc45a93801c5d0acad7d90e4ca3e41cd0b235419c2eeeb6531ca`). Evidence: `docs/evidence/security-s5-apt-lock-correction/`.

## S6
Update success/failure/PDF controls re-certified. Evidence: `docs/evidence/security-gate-s6/`. Security Platform CERTIFIED. Phase 25 READY FOR OWNER AUTHORIZATION. Release NOT AUTHORIZED.
