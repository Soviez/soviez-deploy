# Existing Archive and Retirement Capability Inventory

Classification: **reusable** | **refactor** | **unsafe** | **obsolete** | **duplicate**

| # | Primitive | File / function | Owner | Side | Rev/Dest | Behaviors | Class |
|---|-----------|-----------------|-------|------|----------|-----------|-------|
| 1 | Phase 22 readiness report | `src/migration/phase22_readiness/engine.sh` | 21 | local | reversible | `archives_source=false`, `purges_source=false`, TTL 24h | reusable |
| 2 | Phase 22 readiness CLI | `--migration-phase22-readiness[-show]` | 21 | local | reversible | readiness only | reusable |
| 3 | Source transition | `src/migration/source_transition/engine.sh` | 21 | source | reversible | freeze → maintenance → rollback_origin; **no archive** | reusable → extend |
| 4 | Archive/purge forbid gates | `cutover/codes.sh` `SOVIEZ_MIG_SOURCE_PURGE` / `SOURCE_ARCHIVE` | 21 | flags | deny | die codes | reusable until unlock |
| 5 | Auth-era purge assert | `authorization/codes.sh` | 20 | source | deny | blocks purge mid-auth | reusable |
| 6 | Rollback engine R0–R3 | `rollback/engine.sh` | 21 | both | window-scoped | 1800s window; R3 irreversible via installer | reusable; closure handoff missing |
| 7 | `rollback_window.json` | cutover engine | 21 | op | time-boxed | opens post-cutover | reusable |
| 8 | Stage cutover | `stage_cutover/engine.sh` | 21 | stages | soft | no Stage purge | refactor for archive |
| 9 | Transfer staging cleanup | `transfer/cleanup.sh` | 19 | staging | destructive exact | no Docker prune | reusable pattern |
| 10 | Staging fixture cleanup | `staging/cleanup.sh` | 19 | dest fixture | destructive + confirm | exact names | reusable pattern |
| 11 | Landing cleanup | `landing/cleanup.sh` | 18 | mig subdomain | destructive site | not Production source | reusable for landing only |
| 12 | TLS secret revoke | `tls/engine.sh` `…_tls_revoke` | 18 | cert secrets | destructive rm | local secrets; not CA revoke | refactor; forbid during window |
| 13 | Domain abort | `routing/abort.sh` | 18 | mig DNS/TLS | mostly reversible | preserves owner DNS | reusable abort model |
| 14 | DNS challenge delete | `dns/provider.sh` | 18 | TXT | exact destructive | not A/AAAA purge | reusable |
| 15 | Backup retention cleanup | `backup/retention.sh` | 16 | backups | destructive + pin | policy cleanup | reusable; **not** source retirement |
| 16 | Backup delete CLI | `--backup-delete` | 16 | backup unit | destructive + confirm | pin-protected | reusable UX |
| 17 | Filestore “archive” packaging | `backup/filestore.sh` | 16 | backup | creates package | terminology **duplicate** | duplicate risk |
| 18 | Stage retention delete | `stage/retention_engine.sh` | 13 | Stage | destructive after final backup | never Production | reusable choreography ≠ Migration source |
| 19 | Stage drop | `--stage-drop` | 11/13 | Stage | destructive | confirm | refactor if Phase 22 owns Stage archive |
| 20 | Image prune forbid | `update/images/cleanup.sh` | 15 | images | exact only | forbids `docker prune` | reusable hard ban |
| 21 | Ops retention adapters | ops ledger | 14 | backups | as underlying | may auto-retention | refactor vs never-auto purge |
| 22 | SaaS traffic_owner + `phase22_allowed:false` | `088_migration_traffic_owner.sql` | 21 | SaaS meta | forward | always false | reusable until Phase 22 RPC |
| 23 | SaaS admin license purge | `admin_purge_license_secure` | admin | License SoR | destructive | ≠ migration source | **unsafe** if confused |
| 24 | Sales docs `--purge` | SaaS marketing | docs | points legacy | — | messaging drift | obsolete/unsafe |
| 25 | Legacy `mode_purge` | `soviez-deploy/soviez.sh` | pre-product | tenant stack | irreversible | containers/volumes/nginx/dirs | **unsafe/obsolete** |
| 26 | ERP LG uninstall block | ERP modules | ERP | protect | — | not host purge | reusable integrity |
| 27 | User stub `SOURCE_RETIREMENT.md` | docs/user | planned | user | — | retain/archive/purge; never auto | reusable intent |
| 28 | Constitution §§15–16 | binding | policy | — | never auto purge | reusable |
| 29 | Static forbid tests | `test_phase21_static_forbidden.sh` | 21 | CI | — | ensures archive/purge absent | reusable until Phase 22 |
| 30 | Documented `archive_ready` | Phase 21 SOURCE_TRANSITION_MODEL | 21→22 | source | label | not coded | refactor — implement in 22 |
| 31 | Staging retention pin | `staging/retention.sh` | 19 | staging | soft | default retain UX | reusable |
| 32 | Migration origin grace | Phase 20 rebind | 20 | source License | soft | grace ≠ archived | refactor → finalize in 22 |
| 33 | Destination permanent binding | Phase 20/21 | 20–21 | dest | permanent | one slot | reusable — must not mutate |
| 34 | Pinned source backup | Phase 16/19/21 | 16+ | source backups | retain | pin protect | reusable for archive copies |

## Gaps (must invent in Phase 22)

- Rollback-window **closure** commit (eligibility + owner confirm)
- Stabilization observation beyond 30m immediate window
- Source archive package / verify / restore-test
- Source License final state (`migrated_source_archived`)
- Runtime suspension (ERP stop; optional PG stop; host preserve)
- Credential disposition inventory
- Infrastructure retirement readiness inventory
- Explicit future purge authorization model (**not** in Phase 22 execution)
