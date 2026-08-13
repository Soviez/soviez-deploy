# EXISTING_OFFLINE_BUNDLE_CAPABILITY_INVENTORY

Legend: R=reusable | F=refactor | U=unsafe/incomplete | O=obsolete | D=duplicate risk

| # | Primitive | Location | Owner | Assessment |
|---|-----------|----------|-------|------------|
| 1 | `offline_update_bundle` | SaaS `079`; entitlements catalog | Phase 4 | **R** seed; product_not_launched; no SKU mapping yet |
| 2 | `product_updates` | SaaS 079 + annual map; `src/update/entitlement.sh` | 4/9/15 | **R** exact-License |
| 3 | Annual update eligibility | annual-support + update | 9/15 | **R** |
| 4 | Short-lived private_image_pull | 083 + registry-gateway | 7 | **R** export worker only |
| 5 | Phase 15 update candidate flow | `src/update/*` | 15 | **R** must reuse |
| 6 | Image digest pinning | release/registry | 7/15 | **R** |
| 7 | Addon manifests | update + LG | 15/ERP | **F** |
| 8 | Custom-addon allowlist | LG + validate | 15 | **F** |
| 9 | Phase 16 backup prerequisite | update/backup + backup engine | 16 | **R** |
| 10 | Phase 17 offline pairing packages | migration/pairing/offline.sh | 17 | **R** patterns; not update bundles |
| 11 | Phase 20 offline auth package | migration/authorization/offline.sh | 20 | **R** / **D** if conflated |
| 12 | Device PoP | Phase 5 | 5 | **R** |
| 13 | Signing / trust roots | device, migration sign, release manifests | multi | **F** need purpose keys |
| 14 | Operation engine | src/ops | 14 | **R** |
| 15 | Rollback checkpoints | update/rollback + interrupt | 15 | **R** |
| 16 | Update retry/recovery | update interrupt/recover | 15 | **R** |
| 17 | CLI `--offline-package` | cli + update | 15 | **U** minimum ≠ Phase 23 |
| 18 | Registry credentials | gateway tickets | 7 | **R** short-lived; **U** if persisted |
| 19 | Artifact storage | SaaS registry APIs | 7+ | **F** |
| 20 | Legacy offline deploy | soviez-deploy | legacy | **O/U** |
| 21 | Refund/revoke/dispute | commercial ledger | 3/4 | **R** deny issuance |
| 22 | License Guard independence | ERP LG | ERP | **R** |
| 23 | Phase 23 readiness report | migration/phase23_readiness | 22 | **R** report-only; implements_offline_bundles=false |
| 24 | Phase 24 boundary | MASTER | plan | Security hardening — separate |

### Phase 15 `src/update/offline.sh` gaps
Signature check is non-cryptographic string gate (**U**); no `offline_update_bundle` check (**F**); replay consumed on import before apply (**F**); no OCI packaging/Registry export/receipt/reconcile; comment: not full Phase 23.
