# REGRESSION_RESULTS

## S5 corr suite
`bash tests/security/run_s5_corr_apt_lock.sh` → **PASS**
- `test_s5_corr_apt_lock.sh` PASS
- `test_s5_corr_apt_lock_guest.sh` PASS (22.04 + 24.04)

## Prior gates (non-falsified by corr1 scope)
| Gate | Status |
|------|--------|
| S1–S4 | Prior PASS preserved (not re-opened by corr1) |
| S5 (0.24.5-security-s5) | Prior PASS preserved; corr1 is additive corrective closure |
| Phase 24 security suite | Dist version allowlist accepts `0.24.5.1-security-s5-corr1` |

## Nested full regressions
Authoritative nested S1–S5 + Phase suites via `tests/run_all.sh` → see `RUN_ALL_RESULT.md` (**PENDING** at write time).

## Result
Corr-focused regression **PASS**. Broad run_all **PENDING**.
