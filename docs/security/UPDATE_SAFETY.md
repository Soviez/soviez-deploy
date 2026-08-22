# Update Safety (Security Gate S5 + S6 certification)

Pre-change baseline → controlled mutation → post semantic validation. PASS requires protected network/firewall/port posture and required connectivity checks — not “containers Up”.

## Active policy

- **APT:** wait/backoff only (`soviez_s5_apt_wait_for_lock` / `soviez_security_apt_wait_locks`); never kill apt/dpkg/unattended-upgrades; never blind-rm locks.
- **Engine hooks S5** when `SOVIEZ_S5_ENFORCE=1` or non-test Production path; corr1 APT preflight in `soviez_update_run` (unless `SOVIEZ_S5_SKIP_APT_LOCK=1`).
- **Offline/quarantine modes** adjust outbound expectations.
- **Real PDF path** certified in S6 via Production Odoo image wkhtmltopdf (inject FAIL blocks).
- **Release resolution:** named release → signed metadata → immutable digest (`repository@sha256:…`); `latest` is not deployment authority.

## Current platform build

See `PROJECT_STATE.md` and `dist/soviez.sh.sha256` for the active platform artifact identity. Do not treat historical certification SHA pins below as current operator truth.

## Historical certification (immutable evidence)

| Phase | Artifact | Evidence |
|-------|----------|----------|
| S5 corr1 | `0.24.5.1-security-s5-corr1` | `docs/evidence/security-s5-apt-lock-correction/` |
| S6 | Security Platform CERTIFIED | `docs/evidence/security-gate-s6/` |
| Phase 25 | Engineering 100% | `docs/evidence/phase-25-final-certification/` |

**SUPERSEDED BY:** `docs/SOVIEZ_SH_PRODUCT_CONTRACT.md` and `PROJECT_STATE.md` for operator-facing version/release rules.
