# TEST_RESULTS — Security Gate S1

## Authoritative S1 suite
`tests/security/run_security_gate_s1.sh` → **PASS** (exit 0)

Includes TEST-SEC-001…006, 014…016, fail-closed, idempotency, bootstrap isolation, real runtime, Odoo functional least-privilege + nginx reverse proxy.

## Phase 24 regression
`tests/security/run_phase24_security.sh` → **PASS** (exit 0)
`tools/secret_scan.sh` → **PASS**
dist security scan → **PASS**

## Aggregate
`tests/run_all.sh` → **PASS** — **176 OK / 0 FAIL**, exit **0**

Installer `0.24.1-security-s1`  
SHA256 `4b37198abd25cefa8c822b9b8195fc2adcbbbec47003d4508f23e70d39fa1a96`
