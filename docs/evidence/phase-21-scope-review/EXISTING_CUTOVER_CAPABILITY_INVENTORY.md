# EXISTING_CUTOVER_CAPABILITY_INVENTORY.md

Legend: **R**=reusable, **F**=refactor, **U**=unsafe as-is, **O**=obsolete, **D**=duplicate/shadow, **G**=gap (missing).

| # | Primitive | Path / location | Side | Classification | Notes |
|---|-----------|-----------------|------|----------------|-------|
| 1 | `soviez_migration_assert_no_cutover_dns_purge` | `src/migration/authorization/codes.sh` | installer | **R** | Hard deny today; becomes scoped allow after owner auth |
| 2 | `SOVIEZ_MIG_ALLOW_CUTOVER` / `SOVIEZ_MIG_DNS_CUTOVER` env gates | `authorization/codes.sh`, `common/codes.sh` | installer | **U** | Env flags must not "enable" cutover in production paths |
| 3 | `traffic_cutover_started` / `production_dns_changed` flags | transfer/activation/authorization state JSON | installer | **R** | Canonical cutover progress bits; extend for Phase 21 |
| 4 | `traffic_owner` field (source default) | activation, rebind, ledger mock | installer/SaaS | **F** | Present in mock ledger; needs authoritative cutover flip |
| 5 | `production_licensed_pre_cutover` destination binding | `src/migration/rebind/engine.sh` | installer | **R** | Pre-cutover identity; `public_route=false` |
| 6 | `migration_origin_grace` source grace | `src/migration/grace/` + ledger | installer | **R** | Source traffic epoch; transitions to cutover states in 21 |
| 7 | Phase 21 readiness report signer | `src/migration/phase21_readiness/engine.sh` | installer | **R** | Emits PASS/WARNING/BLOCKED; `phase21_allowed=false` today |
| 8 | Routing plan + `cutover_authorized: false` | `src/migration/routing/readiness.sh` | installer | **R** | Phase 18 artifact; flip only in Phase 21 |
| 9 | Destination plan ERP upstream DISABLED | `src/migration/routing/destination_plan.sh` | installer | **R** | Explicit comment: enabled at Phase 21 |
| 10 | Nginx ownership promote/reload/rollback | `src/nginx/ownership.sh` | installer | **R** | Phase 12; promote Production route on destination |
| 11 | SSL promote / LE challenge / inventory | `src/ssl/promote.sh`, `challenge.sh`, `engine.sh` | installer | **R** | Production TLS on destination before public health |
| 12 | Maintenance landing (mig subdomain) | Phase 18 landing modules | installer | **R** | Distinct from Production maintenance page (Phase 21) |
| 13 | Signed DNS challenge + observation | Phase 18 domain modules | installer | **R** | Pre-cutover ownership proof; not Production A-record switch |
| 14 | Manual DNS instruction renderer | Phase 18 offline/manual path | installer | **R** | First-class for Production cutover; mock/live adapters local |
| 15 | Final sync / source write freeze | `src/migration/final_sync/` | installer | **R** | Phase 19; re-run or delta before cutover commit |
| 16 | Transfer manifest + backup pin gate | `src/migration/transfer/backup_gate.sh` | installer | **R** | Phase 16 pin through 21; rollback prerequisite |
| 17 | Anti-split-brain invariants | Phase 20 models + tests | installer | **R** | Extend for post-cutover detection |
| 18 | Stage rebind (internal) | `src/migration/stage_rebind/` | installer | **F** | Public Stage routing cutover deferred to selected Stages in 21 |
| 19 | Integration neutralization flags | destination binding JSON | installer | **R** | mail/payments/webhooks/cron; activate after health gate |
| 20 | `migration_pre_cutover_reversal` op type | `authorization/codes.sh` | installer | **G** | Stub only; exceptional pre-cutover reversal unimplemented |
| 21 | Legacy `--change-domain` / `--formssl` | `soviez-deploy/soviez.sh` | legacy | **O** | Unsafe for migration cutover; do not invoke |
| 22 | Fixture-only DNS provider adapter | Phase 18 test fixtures | installer | **U** | Not sufficient for live Production DNS |
| 23 | `soviez_update_switch` container cutover | `src/update/switch.sh` | installer | **D** | Version switch semantics; not migration traffic cutover |
| 24 | Wallet `migrate_license_ip` dashboard flow | soviez-saas API | SaaS | **O** | Superseded by Phase 20 ledger path for migration |
| 25 | ERP `local_license_guard` HMAC bind | ERP module | ERP | **F** | Missing grace/pre-cutover/traffic_owner first-class states |
| 26 | Commercial ledger snapshot | `services/migration-authorization-ledger/` | mock/SaaS | **R** | Pattern for cutover audit metadata |
| 27 | Operation engine locks / pause / recover | `src/ops/*` Phase 14 | installer | **R** | Cutover must be one operation family |
| 28 | Source maintenance page model | Phase 18 `MAINTENANCE_LANDING_MODEL` | docs/design | **F** | Production-domain maintenance distinct from mig landing |
| 29 | Health check primitives (ERP `/web/login`) | scattered in validate/activation | installer | **F** | Need formal public health gate post-DNS |
| 30 | Rollback nginx/SSL promote reverse | `ssl/promote.sh` rollback paths | installer | **R** | DNS-only rollback window; unsafe after dest writes |
| 31 | Backup inventory pin/unpin | `src/backup/inventory.sh` | installer | **R** | Protect rollback source backup through cutover |
| 32 | SaaS traffic relay / proxy cutover | — | — | **G** | Explicitly excluded; no SaaS traffic relay |

## Summary counts

| Class | Count |
|-------|-------|
| Reusable (R) | 18 |
| Refactor (F) | 6 |
| Unsafe (U) | 3 |
| Obsolete (O) | 2 |
| Gap (G) | 2 |
| Duplicate (D) | 1 |

## Critical gaps for Phase 21

1. Authoritative `traffic_owner` flip with health-gated commit boundary.
2. Production DNS transition orchestration (manual-first; provider-neutral adapters).
3. Source state machine: `cutover_freeze` → `cutover_maintenance` → `rollback_origin`.
4. Public health/smoke suite bound to Production domain on destination.
5. License Guard recognition of cutover epoch states.
6. Automatic rollback trigger evaluation (advisory vs enforced — owner decision).
