# Failure-injection final matrix

| Failure | Prior coverage | Phase 25 action |
|---------|----------------|-----------------|
| Docker unavailable | P8/P17/P19 | Aggregate + one install E2E negative |
| PostgreSQL unavailable | P16/P19 | Aggregate + restore/migrate negative |
| Registry unavailable | P7/P15 | E2E-03 negative |
| SaaS unavailable | Guard/P10 | E2E-10 |
| DNS/TLS failure | P12/P18/P21 | Cutover/landing negatives |
| Backup failure | P16 | E2E-06 path |
| Disk full | Prior | One disposable negative |
| DB/addon migration failure | P15/P23 | Update offline negatives |
| Candidate/switch/rollback failure | P15 | E2E-03 |
| Offline bundle corruption/bad sig | P23/P24 | E2E-04/09 |
| Ticket replay | P15/P23/P24 | E2E-09 |
| Stage auto-delete failure | P13 | Stage matrix |
| Migration interruption | P19 | E2E-08 |
| Cutover health failure | P21 | E2E-08 |
| Reboot/power loss | P15/P23 | Reboot matrix |
| Evidence finalizer failure | P23 harness | Finalizer self-test |

Material E2E cannot be marker-only.
