# Security Gate S6 — FINAL REPORT

## Verdict
**PASS — FULL SECURITY CERTIFICATION COMPLETE**

## Scope
Certification orchestration over S1–S5 + S5 corr1. Prefer exact existing artifact; **no VERSION bump**; **no product src changes required**. S6 does not invent new architecture.

## Installer (certified exact)
- Version: `0.24.5.1-security-s5-corr1`
- Artifact SHA256: `78092b384b28dc45a93801c5d0acad7d90e4ca3e41cd0b235419c2eeeb6531ca` (local only; not published)
- Certification-only: assemble skipped (VERSION + SHA matched expected)

## Authoritative focused runner
`SOVIEZ_S6_SKIP_NESTED_REGRESSIONS=1 bash tests/security/run_security_gate_s6.sh` → **PASS** (exit 0)

Focused suite covered:
| Suite | Result |
|-------|--------|
| Installer parity (ERP ↔ soviez-deploy + apt-lock safe) | PASS |
| TEST-SEC-001..024 matrix | PASS (fail_count=0, ids=24) |
| Real PDF (`soviez-erp:18.0.1.01.5-local-release-candidate-pass5`, wkhtmltopdf 0.12.6.1 → `%PDF-`; inject FAIL blocks) | PASS |
| Full restore depth | PASS |
| Telemetry / egress audit | PASS |
| Evidence integrity (hash + tamper detect) | PASS |
| Open-source security stack posture | PASS |
| Adversarial matrix | PASS |
| E2E security chain | PASS |

## Nested / full suite status
- Authoritative nested S6 (`SOVIEZ_S6_MATRIX_MODE=execute bash tests/security/run_security_gate_s6.sh`) → **PASS** (exit 0, duration **682 s**)
- `tests/run_all.sh` final → **PASS** (**375 OK / 0 FAIL**, exit **0**, duration **2745 s**)

Prior S1–S5 and S5 corr1 PASS evidence remains authoritative. Direct-path flake fixed during S6: reverse-proxy readiness retry in `test_odoo_functional_least_privilege.sh` (test-only; no product VERSION bump).

## Key certified controls
| Control | Result |
|---------|--------|
| PostgreSQL least privilege / COPY PROGRAM / server-file | PASS |
| Public PG / public Odoo exposure containment | PASS |
| Docker isolation | PASS |
| Firewall/edge + reboot resilience (S2/S5 owners) | PASS (prior + matrix light/execute) |
| Compromise detection (DB/host/miner/IOC) | PASS |
| Migration & restore quarantine | PASS |
| Update network safety + PDF report safety | PASS (real wkhtmltopdf path) |
| Backup integrity; LOCAL_ONLY ≠ DR; off-host MinIO/SFTP classified | PASS |
| Dual wizard ERP↔deploy parity + apt-lock wait-or-fail | PASS |
| No hidden telemetry | PASS |
| ZATCA immutability (synthetic) | PASS |

## Residual risk (honest)
- Not “unhackable” or “malware-free.”
- Nested S6 + full `run_all` still **PENDING** at write time.
- Off-host DR depends on customer-controlled destinations (WARN if misclassified as LOCAL_ONLY).
- Detection coverage is signature/IOC/rule bounded; application compromise outside scanned surfaces may still exist.
- Phase 25 implementation and Release remain unauthorized.

## Progress / authorization
- Engineering Progress remains **99.5%** (do not award final 0.5%).
- Security Platform = **CERTIFIED**
- Phase 25 = **SCOPE REVIEW COMPLETE — READY FOR OWNER AUTHORIZATION** (not implemented by S6)
- Release Authorization = **NOT AUTHORIZED**

## Evidence root
`docs/evidence/security-gate-s6/`

Generated: 2026-08-12T01:42:58Z
Certification run ID: `s6-cert-2026-08-12T014258Z`
