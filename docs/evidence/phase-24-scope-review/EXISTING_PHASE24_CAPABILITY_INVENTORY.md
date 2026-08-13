# EXISTING_PHASE24_CAPABILITY_INVENTORY.md

| # | Primitive | Location | Owner | Status | Class | P24 need | Mutate? |
|---|-----------|----------|-------|--------|-------|----------|---------|
| 1 | Assemble `dist/soviez.sh` | `build/assemble.sh` | build | PASS in use | REUSABLE | syntax/secret scan gate | no redesign |
| 2 | Version / SHA | `PROJECT_STATE`, `dist` header | release | 0.23.0-phase23 | REUSABLE | pin for security cert | version change only if impl |
| 3 | Update engine | `src/update/*` | 15 | PASS | REUSABLE+GAP | STRICT_SIG fail-closed; no fixture token default | harden |
| 4 | Offline update packages | `src/update/offline.sh` | 15 | PASS | GAP | fake-sig policy | harden |
| 5 | Offline bundles | `src/offline_*` | 23 | PASS | REUSABLE | regression | no fork |
| 6 | Registry pull client | `src/registry/pull_client.sh` | 7 | PASS | REUSABLE+GAP | lockdown fail-closed | harden |
| 7 | Bundle registry export | `src/offline_bundle/export/registry.sh` | 23 | PASS | GAP | HOME docker config soft check | harden |
| 8 | Stage ticket helper | `services/stage-operation-helper` | 10.5 | PASS | REUSABLE | replay suite | no fork |
| 9 | Offline bundle replay | `src/offline_bundle/replay.sh` | 23 | PASS | REUSABLE | include in consolidated suite | no |
| 10 | Migration offline seen-hash | `src/migration/pairing/offline.sh` | 17 | PASS | GAP | unsigned offline test flag | harden |
| 11 | Tenant secrets store | `src/tenant/secrets.sh` | 8+ | PARTIAL | GAP | key hashing / at-rest hygiene | yes (scoped) |
| 12 | Redaction | `src/core/redact.sh` | core | PASS | REUSABLE | expand scans | maybe |
| 13 | Security tests | `tests/security/*` | 16–23 | PASS | REUSABLE | add `test_phase24_*` | add |
| 14 | `rg_fallback` | `tests/helpers/rg_fallback.sh` | harness | PASS | REUSABLE | CI | no |
| 15 | `run_all.sh` | `tests/run_all.sh` | harness | PASS | REUSABLE | include P24 | wire |
| 16 | Secret-scan CI | `.github/workflows` | — | **MISSING** | GAP | **implement** | add |
| 17 | service_role deny-list | `src/commands/stage_offline.sh` | 11 | PASS | REUSABLE | clarify acceptance | docs/tests |
| 18 | Phase 24 readiness CLI | `soviez_offline_phase24_readiness` | 23 | WARNING stub | REUSABLE | optional harden | maybe |
| 19 | Unsigned self-update | legacy | obsolete | ABSENT in src | REUSABLE proof | keep absent + doc fix | docs |
| 20 | Privacy doc self-update text | `docs/user/PRIVACY_AND_SOVEREIGNTY.md` | docs | STALE | GAP | correct | docs |
| 21 | Evidence finalizers | phase scripts | 22–23 | PASS | REUSABLE | no false PASS | regression |
| 22 | Ephemeral cert lifecycle | `tests/phase23_ephemeral_*` | 23 | PASS | REUSABLE | pattern for P24 | reuse pattern |
| 23 | SaaS service_role | SaaS DB/RLS | multi | PASS server-side | OUT | no installer embed | frozen UI |
| 24 | Purge commands | denied | 22 | DENIED | OUT | never add | out |

## Duplicate / obsolete

- **Obsolete:** legacy unsigned self-update (`soviez-deploy`) — do not port.
- **Duplicate replay stores:** intentional per-phase (ledger / replay.json / nonces / seen/) — consolidate **certification**, not necessarily one physical store.
- **Duplicate secret scans:** package/import/OCI — keep; add CI umbrella.
