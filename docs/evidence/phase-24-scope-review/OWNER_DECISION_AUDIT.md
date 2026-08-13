# OWNER_DECISION_AUDIT.md

## Must close before Phase 24 **implementation**

| ID | Decision | Why |
|----|----------|-----|
| OD-P24-01 | Confirm corrected title/objective = Security hardening (not purge/release) | Prevents wrong implementation |
| OD-P24-02 | Clarify acceptance: no service-role **credentials** vs no substring in dist | Avoid false FAIL on deny-list |
| OD-P24-03 | At-rest secret policy for activation keys (hash/envelope/OS keychain/keep 0600 plaintext with compensating controls) | “Key hashing” master bullet |
| OD-P24-04 | Production fail-closed signature policy (`STRICT_SIG` default-on?) | Signed-update enforcement |
| OD-P24-05 | Whether test-only unsigned flags remain behind `SOVIEZ_TEST_MODE` only | Ticket/update safety |
| OD-P24-06 | Secret-scan CI vendor/tooling (gitleaks vs trufflehog vs custom rg) | CI workstream |
| OD-P24-07 | Proposed progress weight 0.5 (unapplied) acceptable | Accounting |

## May remain open through Phase 24

| ID | Topic | Notes |
|----|-------|-------|
| Commercial pricing / offline_update_bundle SKU | Phase 23 ODs | Commercial, not security hardening |
| Fleet offline policy | Phase 23 | Policy tuning |
| Purge ownership / retention / legal hold | OD from Phase 22 | **Separate authorization** |
| Phase 11.5 visual acceptance | 11.5 | Deferred |
| Phase 21 historical cutover ODs already implemented under defaults | Many closed by implementation; residual commercial SLA | Not all block P24 |
| Full ERP restore depth | P22 WARNING | Phase 25 matrix / OD |
| Public release / DNS / payment live mutation | Rollout | Not engineering Phase 24 |

## Belongs to Phase 25

- Owner release sign-off
- Full E2E certification matrix execution as release gate
- Docs sync + release checklist completion
- Whether 11.5 visual acceptance blocks “release” language

## Belongs to commercial rollout (not Phase 24/25 engineering alone)

- Live customer activation
- Live entitlement migration
- Live DNS
- Public artifact publish
- Production SLA
- Pricing

## Must not be silently resolved by agents

pricing; retention; purge; revocation; rollout; destructive cleanup; legal hold; public release; production SLA; production DNS; live commercial policy.
