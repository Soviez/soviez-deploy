# TEST_PLAN.md

Implementation-ready matrix for Phase 21 (expand to automated cases when authorized).

## 1. Targeting / prerequisites

| Case | Expected |
|------|----------|
| Exact authorization_id + pair | PASS plan |
| Wrong/expired authorization | BLOCKED |
| Phase 21 readiness expired | BLOCKED |
| Phase 21 readiness BLOCKED | DENY cutover |
| Phase 21 readiness WARNING only optional | PASS per OD-33 |
| Source not in migration_origin_grace | BLOCKED |
| Dest not production_licensed_pre_cutover | BLOCKED |
| Backup pin missing/unpinned | BLOCKED |
| Identity/fingerprint/digest drift | BLOCKED |
| Concurrent transfer op | DENY |
| Env SOVIEZ_MIG_ALLOW_CUTOVER=1 alone | DENY |

## 2. Final sync

| Case | Expected |
|------|----------|
| Skip when grace young | OK |
| Mandatory when grace >24h (OD-02) | BLOCKED if skipped |
| Success delta apply | Report signed |
| Mid-sync failure | Abort; traffic_owner source |
| Idempotent replay | Same outcome |
| Timeout >45m | Abort |

## 3. Source transition

| Case | Expected |
|------|----------|
| grace → freeze on plan | Writes blocked |
| freeze → maintenance on DNS confirm | Maintenance page |
| Writes during maintenance | DENY AR-09 |
| Traffic still source pre-commit | OK |
| Reboot during freeze | Recover state |

## 4. Destination route + TLS

| Case | Expected |
|------|----------|
| Route activate internal verify | upstream ERP |
| nginx -t fail | BLOCKED; rollback promote |
| TLS valid Production FQDN | PASS |
| TLS expired <24h | BLOCKED |
| Cert hostname mismatch | BLOCKED |
| Dest backup post-route (OD-06) | Present |

## 5. DNS transition

| Case | Expected |
|------|----------|
| Instruction emitted signed | Artifact valid |
| Operator attestation recorded | production_dns_changed |
| Propagation 3/5 majority | Proceed health |
| Propagation timeout | Advisory AR-10 |
| No automated live DNS in CI | Mock adapter only |
| Rollback instruction reverse | Correct previous target |

## 6. Health / smoke

| Case | Expected |
|------|----------|
| All mandatory tier PASS | Allow commit |
| /web/login fail | BLOCKED; AR-01 |
| Auth login fail (OD-16) | BLOCKED |
| LG deny destination | BLOCKED |
| Split-brain both public ERP | AR-04 |
| Optional IPv6 fail | WARNING only |
| Retry window 10m exhausted | Recommend rollback |

## 7. Commit boundary

| Case | Expected |
|------|----------|
| Full commit conditions met | traffic_owner=destination |
| Commit without health | DENY |
| traffic_owner dest + public_route false | DENY partial |
| public_route true + traffic_owner source | DENY |
| traffic_cutover_started exactly once | Idempotent |
| SaaS ledger atomic (mock) | Single flip |

## 8. Integrations

| Case | Expected |
|------|----------|
| Mail before health | DENY |
| Mail after commit | Test send OK |
| Payments without checklist attestation | BLOCKED |
| Webhooks source still on | DENY AR conflict |
| Cron neutralized pre-integration | Verified |

## 9. Stage public cutover

| Case | Expected |
|------|----------|
| Mandatory Stage PASS | Complete OK |
| Mandatory Stage FAIL | BLOCKED completion |
| Optional Stage FAIL | WARNING |
| Stage before Production health | DENY order |
| Rollback disables Stage public | Routes off |

## 10. Rollback

| Case | Expected |
|------|----------|
| Pre-commit abort | No DNS change |
| Rollback within 30m zero writes | traffic_owner source |
| Rollback after payment capture | Needs Action |
| Window expired rollback attempt | Advisory/manual |
| Dual-control after T0+15m (OD-24) | Enforced |
| Token not restored | Still consumed |

## 11. Automatic triggers

| Case | Expected |
|------|----------|
| AR-04 split-brain | Enforced per OD-26 |
| AR-01 health flapping 120s grace | Suppressed initially |
| Post-window AR-01 | Advisory only |

## 12. Split traffic

| Case | Expected |
|------|----------|
| Source maintenance during propagation | No ERP writes |
| No 50/50 weighted DNS | N/A forbidden |
| Transient resolver split | Accept with maintenance |

## 13. Security

| Case | Expected |
|------|----------|
| Cross-authorization cutover | DENY |
| Forged health report | Commit DENY |
| Legacy change-domain path | Not invoked |
| Secrets not in DNS artifact | Audit clean |
| Cross-tenant Stage cutover | DENY |

## 14. Operation engine

| Case | Expected |
|------|----------|
| Pause before commit | OK |
| Pause after commit | DENY; use rollback |
| Reboot mid-cutover | Resume correct step |
| Idempotency key replay | Same step result |
| Conflict matrix violations | DENY |

## 15. Data egress

| Case | Expected |
|------|----------|
| SaaS receives metadata only | Audit |
| No business payload upload | Verified |
| Health codes only to SaaS | Per OD-36 |

## 16. Integration E2E (when authorized)

Disposable: mock SaaS ledger + real nginx/ssl fixtures + dual-host migration pair + Phase 20 committed state + mock DNS adapter + ERP health probes.

**Must prove:** Option C sequence end-to-end in mock; rollback within window; no live Production DNS mutation in CI; progress accounting unchanged until PASS.

## 17. Phase overlap regression

| Case | Expected |
|------|----------|
| Phase 20 invariants after 21 abort pre-commit | Unchanged |
| Phase 18 routing plan consumed not regenerated | OK |
| Phase 19 manifest watermark respected | OK |
| Phase 16 backup pin survives | OK |

## 18. License Guard gap

| Case | Expected |
|------|----------|
| LG without traffic_owner support | Documented WARN/BLOCK per OD-38 |
| Future LG with states | Full PASS |

## Banner acceptance (implementation)

Match `CORRECTED_SCOPE.md` binding banner + rollback window state.
