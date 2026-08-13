# REMAINING_TECHNICAL_DEBT.md

| ID | Source | Reference | Impact | Class | Owner |
|----|--------|-----------|--------|-------|-------|
| D24-01 | P15/P23 | `src/update/release.sh` soft STRICT_SIG | Unsigned/soft verify possible outside strict mode | **BLOCKING_PHASE24** | 24 |
| D24-02 | P15 | fixture-token pull fallback | Registry auth bypass in degraded path | **BLOCKING_PHASE24** | 24 |
| D24-03 | P15/P23 | fake/fixture signature escapes outside cert flags | Forged update risk in non-cert runs | **BLOCKING_PHASE24** | 24 |
| D24-04 | P17 | `SOVIEZ_MIG_ALLOW_UNSIGNED_OFFLINE_TEST` | Unsigned migration offline import | **BLOCKING_PHASE24** | 24 |
| D24-05 | P8 | plaintext activation keys in secrets dir | Secret hygiene / “key hashing” gap | **BLOCKING_PHASE24** | 24 (policy OD) |
| D24-06 | P7/P23 | soft `~/.docker/config.json` check | Credential residue | **BLOCKING_PHASE24** | 24 |
| D24-07 | — | No `.github` secret-scan CI in soviez-sh | Master-plan acceptance gap | **BLOCKING_PHASE24** | 24 |
| D24-08 | docs | `PRIVACY_AND_SOVEREIGNTY.md` self-update text | Doc/security mismatch | **BLOCKING_PHASE24** | 24 |
| D24-09 | P10.5/P11 | Stage online vs offline ticket consume cohesion | Replay/cert completeness | **OPTIONAL_HARDENING** / suite | 24 |
| D24-10 | P19 | Deferred “full Phase 24 hardening suite” | Missing consolidated suite | **BLOCKING_PHASE24** | 24 |
| D24-11 | P22 | Full ERP restore WARNING/skipped | Restore depth | **BLOCKING_PHASE25** | 25 matrix / OD |
| D24-12 | P22/P23 | Purge ownership OPEN | Destructive risk if mis-scoped | **DEFERRED_OWNER_DECISION** | separate auth |
| D24-13 | P11.5 | Visual owner acceptance deferred | UX release | **DEFERRED_OWNER_DECISION** | 11.5 / 25 checklist |
| D24-14 | P21 ODs | Many cutover ODs historically open | Policy | **DEFERRED_OWNER_DECISION** | commercial/ops; not all block P24 |
| D24-15 | P23 ODs | Offline bundle commercial ODs | Pricing/fleet | **DEFERRED_OWNER_DECISION** | commercial; not P24 eng |
| D24-16 | P8 | Full ORM E2E activation gap (historical) | Activation depth | **OPTIONAL_HARDENING** | 25 matrix |
| D24-17 | acceptance wording | `service_role` substring in deny-list | False FAIL risk | **DEFERRED_OWNER_DECISION** | clarify OD |
| D24-18 | P23 | Readiness TTL/drift stub | Weak handoff | **OPTIONAL_HARDENING** | 24 optional |
| D24-19 | F31 harness | fail_count double-zero (fixed) | Evidence false FAIL | **RESOLVED** | — |
| D24-20 | Colima default shared | Unrelated wab-poc DBs in default profile | Cert hygiene | **OPTIONAL_HARDENING** | ops / ephemeral profile future |

## Counts

- BLOCKING_PHASE24: D24-01…08, D24-10 (core)
- BLOCKING_PHASE25: D24-11 (and full E2E matrix items)
- DEFERRED_OWNER_DECISION: D24-12…15, D24-17
- OPTIONAL_HARDENING: D24-09, D24-16, D24-18, D24-20
- RESOLVED: D24-19

No discovered blocking defect left **UNKNOWN**.
