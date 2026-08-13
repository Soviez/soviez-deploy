# Decision log

| ID | Decision | Status | Date |
|----|----------|--------|------|
| D001 | Canonical source = `/soviez-sh` | Confirmed | 2026-07-30 |
| D002 | Legacy deploy script read-only during discovery | Confirmed | 2026-07-30 |
| D003 | Auto-activate on `--new`, not `--init` | Confirmed | 2026-07-30 |
| D004 | Keep Stage same-fingerprint model | Confirmed | 2026-07-30 |
| D005 | Do not reuse support RPCs for updates/Stage | Confirmed | 2026-07-30 |
| D006 | Provider-neutral grants; admin first-class | Confirmed | 2026-07-30 |
| D007 | Multi-year Stripe shape | **Resolved:** prepaid `mode=payment` (D042) | 2026-07-30 |
| D008 | Monthly subscriber migration | Requires owner decision | — |
| D009 | Slot commit KEY_ISSUED vs ACTIVATED | Requires owner decision | — |
| D010 | Self-signed transitional SSL policy | Requires owner decision | — |
| D011 | Registry Hub vs GHCR | Requires owner decision | — |
| D012 | `--init` requires Cloud auth? | Requires owner decision | — |
| D013 | Phase 3: additive commercial ledger + dual-write; License Slot auth remains on legacy `purchases` RPCs until explicit cutover phase | Confirmed (implemented PARTIAL gate) | 2026-07-30 |
| D014 | Admin/offline grants classify as `admin_grant` with `provider_reference=null` (no fabricated Stripe settlement in neutral model) | Confirmed | 2026-07-30 |
| D015 | Partial-refund grant policy beyond legacy behavior | Preserve legacy; unresolved business policy | 2026-07-30 |
| D016 | When to drop synthetic `admin-grant-*` / `admin-addon-*` session IDs | Requires owner decision (retain while dual-write) | — |
| D017 | When to switch `get_available_license_slots` to neutral grants | After proven parity + owner auth (not Phase 3/4) | — |
| D018 | Phase 4 hybrid materialization: catalog+mappings expand commercial_grants; strict resolver service-role only; no production auth cutover | Confirmed (implemented PARTIAL gate) | 2026-07-30 |
| D019 | `valid_from` inclusive / `valid_until` exclusive (UTC) for entitlement windows | Confirmed | 2026-07-30 |
| D020 | Legacy support slug maps technical_support only; fail closed for product_updates | Confirmed | 2026-07-30 |
| D021 | past_due: preserve legacy support RPC behavior; do not broaden strict product_updates | Confirmed | 2026-07-30 |
| D022 | Phase 3–4 consolidated hardening closed PARTIAL→PASS with isolated Docker E2E + typed schema + materialize structured result | Confirmed PASS | 2026-07-30 |
| D023 | Phase 5 device auth: Ed25519 raw keys; opaque hashed credential + mandatory PoP; dedicated signing domain `soviez.device-auth.v1`; no commercial entitlement from device link alone | Confirmed PASS | 2026-07-30 |
| D024 | Phase 5 weight = 6 (owner confirmed) | Confirmed | 2026-07-30 |
| D025 | Device private key planned paths `/etc/soviez/device/*` — installer file creation deferred to later phase | Confirmed | 2026-07-30 |
| D026 | Phase 6 weight = 5 (owner confirmed) | Confirmed | 2026-07-30 |
| D027 | Phase 6 consumption: soft-commit at key_issued via purchase mint; reservation holds withhold capacity without early license_slots_used bump | Confirmed PASS | 2026-07-30 |
| D028 | Additive `generate_secure_license_for_purchase`; portal `generate_secure_license_1to1` preserved; manual claim bridge for matching reservation | Confirmed | 2026-07-30 |
| D029 | Phase 7: separate Node streaming gateway for OCI blobs; SaaS issues tickets only; Vercel/Next.js not used for blob proxy | Confirmed PASS | 2026-07-30 |
| D030 | Phase 7: Ed25519 pull tickets domain `soviez.registry-pull-ticket.v1`; release manifests `soviez.release-manifest.v1`; Hub creds gateway-only | Confirmed PASS | 2026-07-30 |
| D031 | Phase 7: digest-first release catalog migration `083`; capability `private_image_pull` via commercial_grants (seed mapping, no auto-grant) | Confirmed PASS | 2026-07-30 |
| D032 | Phase 7 weight = 6 (owner confirmed) | Confirmed | 2026-07-30 |
| D033 | Running ERP never depends on registry/SaaS availability; pull is optional connected op | Confirmed PASS | 2026-07-30 |
| D034 | Phase 7 installer wiring + live Hub cutover deferred; foundation APIs + gateway only | Confirmed | 2026-07-30 |
| D035 | Phase 8: modular `src/` assembled to `dist/soviez.sh`; never edit dist directly | Confirmed PARTIAL | 2026-07-30 |
| D036 | Phase 8: ORM activation via `action_activate_soviez_license`; key staged stdin→0600 file; never argv/logs | Confirmed PARTIAL | 2026-07-30 |
| D037 | Phase 8: auto on `--new` only (not `--init`); manual path ends `completed_activation_pending` | Confirmed PARTIAL | 2026-07-30 |
| D038 | Phase 8: `--reattach` resume from persisted operation state; idempotent step guards | Confirmed PARTIAL | 2026-07-30 |
| D039 | Phase 8: `local_license_guard` read-only; fingerprint cert via `license_tools` import only | Confirmed PARTIAL | 2026-07-30 |
| D040 | Phase 8 weight = 7; PARTIAL gate — no weight awarded until full Odoo container ORM E2E | Confirmed PARTIAL | 2026-07-30 |
| D041 | Phase 8: ShellCheck unavailable on certification host; `bash -n` substituted | Confirmed | 2026-07-30 |
| D042 | Phase 9: Prepaid Annual Support uses Stripe Checkout `mode=payment`, not N-year subscription | Confirmed PASS | 2026-07-30 |
| D043 | Phase 9: Multi-year discounts admin-configurable via `support_term_discount_rules`; seed only 1y @ 0% | Confirmed PASS | 2026-07-30 |
| D044 | Phase 9: Monthly new sales blocked server-side; legacy monthly renewals preserved | Confirmed PASS | 2026-07-30 |
| D045 | Phase 9: Coverage history authoritative (`support_coverage_periods`); extension stacks `max(valid_until, now)` | Confirmed PASS | 2026-07-30 |
| D046 | Phase 9: Partial refund → `requires_admin_review`; no automatic proration (D015 preserved) | Confirmed PASS | 2026-07-30 |
| D047 | Phase 9: Runtime independence — expiration does not stop ERP; no installer phone-home this phase | Confirmed PASS | 2026-07-30 |
| D048 | Phase 9 weight = 5; `--update` integration deferred | Confirmed PASS | 2026-07-30 |
| D049 | Phase 10: Stage License monthly subscription; exact license_id; unlimited commercially; expiration does not stop existing Stages | Confirmed PASS | 2026-07-30 |
| D050 | Phase 10: Gated ops (create/clone/refresh/rebuild) vs local ops (list/status/stop/backup/drop) | Confirmed PASS | 2026-07-30 |
| D051 | Phase 10: One-active entitlement supersession per license; no license slot consumption | Confirmed PASS | 2026-07-30 |
| D052 | Phase 10 weight = 5; installer `--stage` wiring deferred | Confirmed PASS | 2026-07-30 |
| D053 | Phase 10.5: Stage Operation Tickets use dedicated signing domain `soviez.stage-operation.v1` — separate from Device Auth, License, release-manifest, registry pull, Migration HMAC, Stripe | Confirmed | 2026-07-30 |
| D054 | Phase 10.5: Ticket `exp` gates START of gated Stage ops only; never stops existing Stages; Stage License expiry still does not stop/delete Stages | Confirmed | 2026-07-30 |
| D055 | Phase 10.5: Local verifier is Node TypeScript helper (`stage-operation-helper`), not Bash-only; Bash cannot certify Stages by local Boolean | Confirmed | 2026-07-30 |
| D056 | Phase 10.5: Tooling packaging `signed_package`, digest-pinned private registry; fixture digest `sha256:aaa…a` for tests | Confirmed | 2026-07-30 |
| D057 | Phase 10.5: Traceability limited to `delivery_trace_id` + `subject_pseudonym` (license hash); no name/email/business data; origin cert local evidence only | Confirmed | 2026-07-30 |
| D058 | Phase 10.5: Explicit non-DRM — Full Root can replace verifier / rewrite offline ledger; residual risk accepted and disclosed | Confirmed | 2026-07-30 |
| D059 | Phase 10.5 weight = 4; expected cumulative PASS `48+4=52%`; Phase 11 / `--stage` / Stage containers / `local_license_guard` change unauthorized | Confirmed PASS (superseded by Phase 11 auth) | 2026-07-30 |
| D060 | Phase 11: each Stage gets a **dedicated** Docker network `soviez-net-stage-<id>` (not shared legacy `soviez-net-stage`) | Confirmed PASS | 2026-07-30 |
| D061 | Phase 11: Production snapshot via `pg_dump -Fc` + filestore copy/rsync — never copy live PostgreSQL data directory; never shared writable filestore | Confirmed PASS | 2026-07-30 |
| D062 | Phase 11: commercial Stage count unlimited; local resource admission may block/warn (disk/memory/load) | Confirmed PASS | 2026-07-30 |
| D063 | Phase 11: Stage does not consume Core License Slot; binds exact Production license/fingerprint/DB UUID | Confirmed PASS | 2026-07-30 |
| D064 | Phase 11: trusted CA SSL required for Stage PASS; self-signed rejected as final acceptance | Confirmed PASS | 2026-07-30 |
| D065 | Phase 11: neutralization + origin cert require Node helper — Bash Boolean alone cannot certify; not DRM (Full Root residual) | Confirmed PASS | 2026-07-30 |
| D066 | Phase 11 weight = 8; PASS cumulative `52+8=60%`; Phase 12 unauthorized; retention auto-delete deferred to Phase 13 | Confirmed PASS | 2026-07-30 |
| D067 | Phase 11 first certification was PARTIAL (fixture dumps; offline request-only; disconnect not exercised). Gap closure: live disposable Postgres dump/restore; full offline import→create; durable worker disconnect/resume + disposable container reboot under `$HOME` mounts | Confirmed PASS | 2026-07-30 |
| D068 | Phase 11 resume semantics: `soviez_stage_sm_should_run` uses strict `<` so completed checkpoints are not re-executed; filestore promote never `mv` into existing dest dir | Confirmed PASS | 2026-07-30 |
| D069 | Phase 11.5: Complete Customer IA (8 sections) + Admin IA (7 sections) for all Phase 3-11 capabilities | OWNER REVIEW READY | 2026-07-30 |
| D070 | Phase 11.5: Monthly Support new-sales retirement — existing subscriptions preserved, new purchases blocked with clear error UX | OWNER REVIEW READY | 2026-07-30 |
| D071 | Phase 11.5: Stage License monthly subscriptions preserved — different product from Technical Support monthly | OWNER REVIEW READY | 2026-07-30 |
| D072 | Phase 11.5 acceptance preview is the **real** SaaS app on `http://127.0.0.1:3011/login` with demo Supabase + Stripe test; fixture/`?preview=1` is **not** the acceptance path | OWNER REVIEW READY | 2026-07-30 |
| D073 | Phase 11.5: Error UX with structured denial codes — all 6 error scenarios have clear recovery workflows | OWNER REVIEW READY | 2026-07-30 |
| D074 | Phase 11.5: WCAG 2.1 AA accessibility, mobile responsive design, RTL/Arabic support per Soviez RTL Design Standard | OWNER REVIEW READY | 2026-07-30 |
| D075 | Phase 11.5: Browser automation tests + contract tests covering all customer/admin workflows and error scenarios | OWNER REVIEW READY | 2026-07-30 |
| D076 | Phase 11.5: No breaking changes — all existing Phase 3-11 functionality preserved, additive-only implementation | OWNER REVIEW READY | 2026-07-30 |
| D077 | Phase 11.5 weight = 5; technical gates PASS; owner acceptance required for progress credit (60% → 65%); Phase 12 unauthorized | OWNER REVIEW READY | 2026-07-30 |
| D078 | Phase 11.5 Round 3: demo schema 078–086 via pooler; Stripe test pay→Annual coverage + Stage entitlement; Playwright 12/12; Annual fulfill no longer short-circuits on paid; Stage subscription purchase finder includes Stage slug | OWNER REVIEW READY | 2026-07-30 |
| D079 | Phase 11.5 Round 3 verdict: `OWNER REVIEW READY — REAL SAAS INTEGRATION COMPLETE`; progress remains 60% until owner PASS | OWNER REVIEW READY | 2026-07-30 |
| D080 | Phase 11.5 Round 4: approved Instance design implemented + `crypto.randomUUID` checkout fix; progress still 60% | OWNER REVIEW READY | 2026-07-30 |
| D081 | Phase 11.5 functional freeze: no further SaaS functional changes required before installer work; visual/UI acceptance deferred; trees remain uncommitted; **no** 65% credit without owner PASS | FUNCTIONALLY CERTIFIED — VISUAL DEFERRED | 2026-07-30 |
| D082 | Next `soviez.sh` phase was listed as Phase 12 Mandatory Stage domain/SSL (pending owner auth) — **superseded by D083 scope correction** | SUPERSEDED | 2026-07-30 |
| D083 | Phase 12 title/scope corrected: **Domain/SSL Lifecycle Hardening, Renewal, Recovery, and Production Policy**. Phase 11 retains initial Stage domain/DNS/trusted SSL/self-signed rejection/Nginx Stage route. Phase 12 owns post-provision lifecycle only. | SCOPE CORRECTED | 2026-07-30 |
| D084 | Phase 12 Production/Stage SSL owner decisions (public CA default, temporary HTTP, readiness, 30-day renewal, backoff, automatic mode, failure=needs_action, Stage≠stop, wildcard optional, Let's Encrypt default + fixture) **confirmed and implemented** | CONFIRMED PASS | 2026-07-30 |
| D085 | Phase 12 weight = 4; PASS cumulative `60+4=64%`; Phase 11.5 remains uncredited; Phase 13 unauthorized | PASS | 2026-07-30 |
| D086 | Phase 13 retention default is 14 calendar days from immutable original Stage creation; absolute maximum is 60 calendar days from that same creation timestamp | CONFIRMED PASS | 2026-07-30 |
| D087 | `--days` expresses requested total lifetime, is monotonic, and never resets the retention clock; UTC persistence with host-timezone calendar-day/end-of-day semantics | CONFIRMED PASS | 2026-07-30 |
| D088 | Retention is independent of Stage License and ticket entitlement; local warning/countdown, final backup, Safe Shield, exact-resource deletion, tombstone, and Needs Action on ambiguity | CONFIRMED PASS | 2026-07-30 |
| D089 | Phase 13 weight = 3; PASS cumulative `64+3=67%`; Phase 11.5 remains uncredited and Phase 14 is unauthorized | PASS | 2026-07-30 |
| D090 | Phase 14 title/scope corrected: **Unified Operation Engine Consolidation and Cross-Command Recovery**. Old “Persistent operation engine” (first-time persistence/systemd/reattach) is obsolete — those capabilities already exist across Phases 8/11/12/13 | SCOPE CORRECTED | 2026-07-31 |
| D091 | Phase 14 proposed weight = 5; progress credited; implementation authorized by corrected scope | CONFIRMED PASS | 2026-07-31 |
| D092 | Phase 14 Unified Operation Engine Consolidation implementation complete and certified PASS; progress credited to 72%; Phase 15 remains unauthorized | CONFIRMED PASS | 2026-07-31 |
| D093 | Phase 14 corrective canonical synchronization closure complete and certified PASS; continuous sync protocol documented and verified | CONFIRMED PASS | 2026-07-31 |
| D094 | Phase 15 Safe Update: exact Production target; product_updates Annual gate; digest-pinned candidate update; proposed weight 6; PARTIAL until Docker ERP-image upgrade + reboot matrix | Confirmed PARTIAL | 2026-07-31 |
| D095 | Phase 15 final certification: real Docker Colima ERP upgrade E2E; LG contract `soviez.update-candidate-identity.v1` (no bypass/slot); Colima reboot matrix; image retention/cleanup with supersede vs `production_update`; weight 6 credited → **84%**; Phase 16 unauthorized | Confirmed PASS | 2026-07-31 |
| D096 | Phase 16 title/scope corrected: **Production Backup, Restore, Verification, and Recovery Management**. Old “Keep backup; add restore” obsolete — soviez-sh had no Production `--backup`/`--restore`; Stage/retention/update paths are not the product; legacy has backup only. Proposed weight **6** uncredited at review; OD-01…OD-18 were pending | SCOPE REVIEW COMPLETE — SUPERSEDED BY D097 | 2026-08-01 |
| D097 | Phase 16 implemented PARTIAL: modular `src/backup/*` + `src/restore/*`; CLI `--backup`/`--restore` family; openssl aes-256-cbc pbkdf2; local enc default ON / remote mandatory; destinations local+S3/SFTP profiles (TEST_MODE filesystem fixtures; MinIO/real SSH e2e open); retention 7/4/12 + pins; schedule 02:00 local; candidate-first restore + 24h safety; Stage live via `soviez_backup_stage_live_backup`; cross-host deny; no SaaS backup; no WAL/PITR; installer **0.16.0-phase16**; weight **6** **not** credited → progress remains **84%**; Phase 17 NOT authorized; OD-01…OD-18 product decisions closed; certification gaps: MinIO multipart, real SFTP server, real ERP `/web/login` restore candidate, fuller host-reboot matrix | CONFIRMED PARTIAL | 2026-08-01 |
| OD-01 | Local encryption: default ON; advanced opt-out `SOVIEZ_BACKUP_DISABLE_ENCRYPTION=1`; remote always mandatory | Confirmed (implemented) | 2026-08-01 |
| OD-02 | First remotes: S3-compatible + SFTP (owner-controlled); Soviez-hosted out of scope | Confirmed (implemented) | 2026-08-01 |
| OD-03 | Indefinite pins allowed; pins protected from retention automation | Confirmed (implemented) | 2026-08-01 |
| OD-04 | Default retention classification: 7 daily / 4 weekly / 12 monthly | Confirmed (implemented) | 2026-08-01 |
| OD-05 | Automated restore drills: `backup_restore_test` / `--restore-test` implemented now | Confirmed (implemented) | 2026-08-01 |
| OD-06 | Database-only backup: advanced-only (`--type database-only --advanced`); not a Full restore source | Confirmed (implemented) | 2026-08-01 |
| OD-07 | Incremental/WAL/PITR: **deferred** — not in Phase 16 | Confirmed deferred | 2026-08-01 |
| OD-08 | Cross-host restore: **denied** in Phase 16; belongs to Phase 17/migration | Confirmed (implemented deny) | 2026-08-01 |
| OD-09 | Restore-as-Stage allowed via `--restore-as-stage` subject to Stage entitlement/domain rules | Confirmed (implemented) | 2026-08-01 |
| OD-10 | Default scheduled backup time: **02:00 server-local** | Confirmed (implemented) | 2026-08-01 |
| OD-11 | Backup concurrency: conflict-locked Production backup (queue/deny via ops engine) | Confirmed (implemented) | 2026-08-01 |
| OD-12 | Default resource profile `balanced`; capacity preflight with overhead margins | Confirmed (implemented) | 2026-08-01 |
| OD-13 | Restore rollback safety window: **24h** (`SOVIEZ_RESTORE_SAFETY_WINDOW_HOURS`) | Confirmed (implemented) | 2026-08-01 |
| OD-14 | Destination profiles local; schedules bind per-Production destination profile | Confirmed (implemented) | 2026-08-01 |
| OD-15 | Destination credentials / encryption keys: **local only** — no SaaS custody | Confirmed (implemented) | 2026-08-01 |
| OD-16 | Retention automation may delete eligible unpinned backups with confirm gates; manual delete always confirm; pins protected | Confirmed (implemented) | 2026-08-01 |
| OD-17 | Verification before counting as latest verified / preferred restore source | Confirmed (implemented) | 2026-08-01 |
| OD-18 | Portable Full format: `pg_dump -Fc` + filestore archive + `soviez.backup.v1` signed manifest | Confirmed (implemented) | 2026-08-01 |


## D098 — Phase 16 final certification closure PASS (2026-08-01)

Closed remaining PARTIAL gaps with disposable MinIO multipart S3, real OpenSSH/SFTP strict host-key,
real ERP restore-test (`/web/login`), Colima host reboot matrix, Stage live-DB reconfirm, and full `tests/run_all.sh` PASS.
Progress credited 78+6 = **84%**. Phase 17 remains unauthorized. No commit/push/deploy.

## D099 — Phase 17 scope review and correction (2026-08-01)

Phase 17 corrected to **Migration Discovery, Trust Pairing, and Destination Bootstrap**. Inspection: no `src/migration/`; no `--merge-in`/`--migrate-in` CLI; legacy has `--init` + LG `SOVIEZ_MIGRATION_SECRET` only; SaaS `migration_token` + `begin_license_migration`/`migrate_license_ip` exist for Phase 20 burn — Phase 17 eligibility-only (`consumed=false`). Reuse Phases 5–16; exclude 18–22 work. Proposed weight **5** uncredited; progress stays **84%**; installer `0.16.0-phase16` unchanged. OD-01…OD-25 open. Evidence: `docs/evidence/phase-17-scope-review/`. Implementation **NOT authorized**. No commit/push/deploy.

## D100 — Phase 17 implementation PARTIAL (2026-08-01)

Implemented `src/migration/**` + CLI `--migration-*` + ops conflicts; installer **`0.17.0-phase17`**; binding ODs applied (24h TTL, 5m skew, 25% margin, amd64-only, Ubuntu 22.04/24.04, token eligibility-only, Stages unselected). Unit/security/reboot PASS; `tests/run_all.sh` PASS. **PARTIAL** because destination OS/host bootstrap certification used Darwin fixtures for Ubuntu policy (no disposable Ubuntu VM e2e yet). Weight **5** **not** credited → progress remains **84%**. Phase 18 UNAUTHORIZED. No commit/push/deploy. Evidence: `docs/evidence/phase-17-migration-discovery-bootstrap/`.

## D101 — Phase 17 final certification closure PASS (2026-08-01)

Closed all PARTIAL gaps: real Ubuntu 22.04/24.04 amd64 destination bootstrap (`SOVIEZ_MIG_REQUIRE_REAL_HOST=1`); signed installer crypto; real mTLS handshake; offline pairing; source non-disruption (Postgres+HTTP); Migration Token ledger non-reservation/non-consumption; readiness PASS/WARNING/BLOCKED + invalidation; Colima host reboot matrix; multi-tenant isolation; scoped no-payload/secret gates. Full-permission `tests/run_all.sh` **PASS** (sandbox-constrained failure preserved as environment-access limitation). Weight **5** credited → progress **89%** (84+5). Installer remains **`0.17.0-phase17`**. Phase 18 UNAUTHORIZED. No commit/push/deploy. Evidence: `docs/evidence/phase-17-final-certification-closure/`.

## D102 — Phase 18 scope review and correction (2026-08-02)

Corrected title to **Maintenance Landing, Signed Domain Validation, and Migration Routing Readiness**. Inspected Phase 12 SSL/Nginx, Phase 17 pair/bootstrap, legacy `--change-domain`/`--formssl`, SaaS (no DNS-provider credential API). Canonical default: dedicated `migrate.<production-domain>`; manual DNS; TXT+reachability; mig-subdomain TLS; no Production cutover; Abort preserves owner DNS and source traffic. Proposed weight **4** uncredited. Progress remains **89%**; installer **`0.17.0-phase17`** unchanged; no runtime/`dist` changes. Implementation **NOT authorized**. Phase 19 UNAUTHORIZED. Evidence: `docs/evidence/phase-18-scope-review/`. No commit/push/deploy.

## D103 — Phase 18 implementation PASS (2026-08-02)

Implemented `src/migration/{domain,dns,landing,tls,routing}/**` + CLI flags; installer **`0.18.0-phase18`**. Defaults: `migrate.<production-domain>`; TXT `_soviez-migration.<migration-fqdn>`; challenge TTL 30m; routing readiness 24h; manual DNS first-class; mock provider for tests; Abort preserves owner DNS. Unit (38), security static gates (no source mutation / no payload transfer), multi-tenant isolation, host-disk reboot matrix PASS. E2E suite: CoreDNS auth + dual recursive forwarders + nginx landing + real Pebble 2.7.0/lego with `PEBBLE_VA_ALWAYS_VALID=1` (order/CSR/issue/chain real; VA short-circuited — documented). Weight **4** credited → progress **93%** (89+4). Phase 19 UNAUTHORIZED. No live systems changed. No commit/push/deploy. Evidence: `docs/evidence/phase-18-migration-domain-routing/`.

## D104 — Phase 19 scope review and correction (2026-08-02)

Corrected title to **Direct Streaming Migration, Resumable Transfer, and Destination Staging**. Inspected Phase 16 backup/restore/SFTP/S3, Phase 17 mTLS/pair/token eligibility/`assert_no_transfer`, Phase 18 routing readiness, Stage live backup, update-candidate analogy, legacy deploy backup, SaaS migrate begin/consume (Phase 20). Recommended **Option B** (multi-pass pre-sync + short final write freeze; Phase 16 `-Fc` final DB; no WAL/PITR). Boundaries: no token reserve/consume, no destination Production activation, no cutover, source remains ACTIVE. Proposed weight **5** uncredited (remaining budget **7%**). Progress remains **93%**; installer **`0.18.0-phase18`** / SHA256 `5d2979b406a3fdb97646c69a8623cd526c97915a6a16eb183a0ab8ef768007b3` unchanged; no runtime/`dist` changes. Implementation **NOT authorized**. Phase 20 UNAUTHORIZED. Evidence: `docs/evidence/phase-19-scope-review/`. No commit/push/deploy.

## D105 — Phase 19 implementation PARTIAL (2026-08-02)

Implemented modular `src/migration/{transfer,database,filestore,addons,config,stages,staging,final_sync}/**` + CLI transfer/presync/abort commands; installer **`0.19.0-phase19`**. Delivered: signed transfer plan/manifest, pair-bound mTLS chunk channel (dedicated unit PASS), local-channel default e2e, chunk registry/resume, backup gate ≤24h VERIFIED, freeze marker + hard timeout/watchdog/reconcile, pg_dump -Fc path, filestore pre-sync/delta, sanitized config + secret inventory (no auto secret transfer), Stage selection/eligibility, destination staging identity (no slot/public route/token mutation), Abort preserves staging. **PARTIAL** — default e2e local channel; freeze fixture in most suites; reboot matrix skip Colima by default; destination ERP fixture login HTML; Stage not full live multi-Stage ERP. Weight **2 not credited**; progress remains **93%**. Phase 20 UNAUTHORIZED. No live systems/data changed. No commit/push/deploy. Evidence: `docs/evidence/phase-19-direct-streaming-migration/`.

## D106 — Phase 19 final certification gap closure PASS (2026-08-02)

Closed G1–G10 without Phase 20 scope. Certification gates forbid local-copy/fixture DB/ERP/reboot-skip/network-skip. Authoritative E2E uses real mTLS, real PostgreSQL 16 `pg_dump -Fc` / `pg_restore`, real `soviez/erp` staging (`/web/login` 200), application write-guard freeze + watchdog, real Stage selection semantics, actual Colima host reboot matrix, network interruption + failure-injection + adversary matrices. `tests/run_all.sh` one clean full-permission run: **PASS** exit **0** (73 OK). Installer remains **`0.19.0-phase19`**; SHA256 `eb7f29235d352db6cfe47a0c065d3eaa81104047d80ab7e3ab351dd6f51c25fc`. Weight **2** credited → progress **95%** (93+2). Phase 20 UNAUTHORIZED. No token reserve/consume, no destination Production activation, no DNS/cutover, source remains active, freeze released at terminal. No live customer systems/data changed. No commit/push/deploy. Evidence: `docs/evidence/phase-19-direct-streaming-migration/` (PARTIAL report preserved).

## D107 — Phase 20 scope review and correction (2026-08-02)

Corrected title to **Atomic Migration Authorization, Token Consumption, License Rebind, and Destination Activation**. Inspected Phase 4 ledger/`migration_token` shadow grants, wallet `begin_license_migration`/`migrate_license_ip`, slot idempotency, Phase 17–19 pair/staging/`ready_for_20`/`assert_no_cutover_or_token`, LG `SOVIEZ_MIGRATION_SECRET` naming collision, dashboard migrate wizard. Recommended: no long-lived reservation; SaaS atomic commit (consume IFF dest binding + source grace authz); source `migration_origin_grace`; dest `production_licensed_pre_cutover`; anti-split-brain; honest offline limits; Phase 21 readiness PASS/WARNING/BLOCKED; stop before DNS/cutover. Proposed progress weight **1** uncredited (budget 5% for 20–25; complexity Very High). Progress remains **95%**; installer **`0.19.0-phase19`** / SHA unchanged; no runtime/`dist` changes. OD-01…OD-50 open. Implementation **NOT authorized**. Phase 21 UNAUTHORIZED. Evidence: `docs/evidence/phase-20-scope-review/`. No commit/push/deploy.

## D108 — Phase 20 implementation PASS (2026-08-03)

Implemented and certified **Atomic Migration Authorization, Token Consumption, License Rebind, and Destination Activation**. Installer **`0.20.0-phase20`** SHA256 `4e4eafc9ebb1fe8db62b789faead89476b03455536e5c1cd33e6c470963288d9`. Canonical SoR: SaaS `commit_migration_authorization` (`087`) + TS client; certification mirror: SQLite fixture ledger. Dual truth closed (grant+wallet atomic; obsolete consume blocked). Source `migration_origin_grace`; destination `production_licensed_pre_cutover`; anti-split-brain; offline committed package; Phase 21 readiness PASS/WARNING/BLOCKED; no DNS/cutover/source purge. Focused Phase 20 suites PASS; disposable PG commit proof PASS; SaaS typecheck/lint/build PASS; authoritative `tests/run_all.sh` PASS exit **0** (77 OK). Weight **1** credited → progress **96%** (95+1). Phase 21 **UNAUTHORIZED**. No live systems/data changed. No commit/push/deploy. Evidence: `docs/evidence/phase-20-atomic-authorization-rebind/`.

## D109 — Phase 21 scope review and correction (2026-08-03)

Corrected title to **Production Traffic Cutover, DNS Transition, Health Validation, and Immediate Rollback**. Inspected Phase 18 domain/DNS/TLS/landing/routing, Phase 19 freeze/final sync, Phase 20 grace/pre-cutover/split-brain/readiness, Phase 12 nginx/SSL, Phase 16 backup pin, legacy `--change-domain`, ERP LG gaps, SaaS auth receipts. Recommended **Option C** hybrid cutover; commit = route+DNS+TLS+public health+`traffic_owner=destination`+source writes blocked; rollback window **30m**; DNS-only rollback unsafe after meaningful dest writes. Proposed progress weight **1** uncredited (budget ~4% for 21–25; complexity Very High). Progress remains **96%**; installer **`0.20.0-phase20`** / SHA unchanged; no runtime/`dist` changes. OD-01…OD-50 open. Implementation **NOT authorized**. Phase 22 UNAUTHORIZED. Evidence: `docs/evidence/phase-21-scope-review/`. No commit/push/deploy.

## D110 — Phase 21 implementation PASS (2026-08-03)

Implemented and certified **Production Traffic Cutover, DNS Transition, Health Validation, and Immediate Rollback**. Installer **`0.21.0-phase21`** SHA256 `b95203dbb6073362cc1215272e6e837ee75cc366f78ac2c7d09150a554ec462d`. Hybrid cutover: final sync/freeze→maintenance, local-CA Production TLS, exact Nginx route, DNS mutate + real disposable authoritative dig quorum, traffic_owner destination after health, 30m rollback window, R3 unsafe denial, Phase 22 readiness without archive. SaaS `088` traffic_owner metadata RPC. Focused Phase 21 suites PASS; `tests/run_all.sh` PASS exit **0** (82 OK). Weight **1** credited → progress **97%** (96+1). Phase 22 **UNAUTHORIZED**. No live systems/data changed. No commit/push/deploy. Evidence: `docs/evidence/phase-21-production-cutover/`.

## D111 — Phase 22 scope review and correction (2026-08-04)

Corrected title to **Rollback Window Closure, Source Archive, License Finalization, and Safe Retirement Readiness**. Separated **ARCHIVE** (reversible) from **PURGE** (destructive; excluded from Phase 22). Inspected Phase 16 backup/retention, Phase 20 grace/slot, Phase 21 rollback window / source_transition / phase22_readiness, Stage retention, update prune bans, legacy `mode_purge`, SaaS admin license purge messaging. Recommended: automatic eligibility + explicit owner confirmation to close rollback; 24h stabilization (not archive at 30m); source archive VERIFIED + DB restore test; License `migrated_source_archived`; runtime Option B (stop ERP, preserve host); no backup/cert/DNS deletion; credentials disposition not silent destroy; purge ownership **OPEN** (master-plan Phase 23 remains Offline bundles — do not silently assign purge). Proposed progress-accounting weight **1** uncredited (~3% remains for Phases 22–25; real complexity Medium–High). Progress remains **97%**; installer **`0.21.0-phase21`** / SHA unchanged; no runtime/`dist` changes. OD-01…OD-50 open. Implementation **NOT authorized**. Phase 23 UNAUTHORIZED. Evidence: `docs/evidence/phase-22-scope-review/`. No commit/push/deploy.

## D112 — Phase 22 implementation PASS (2026-08-04)

Implemented and certified **Rollback Window Closure, Source Archive, License Finalization, and Safe Retirement Readiness**. Installer **`0.22.0-phase22`** SHA256 `b8df40b6a2e3fa4a15b16953812f74c789b2396a9dbaad4bf4c6e9e57408d274`. Stabilization multi-tick + inject fail-closed; owner confirm phrase closes rollback window idempotently; reversible encrypted source archive with real PG restore (docker `postgres:16-alpine`) and filestore verify; full ERP restore WARNING/skipped via `SOVIEZ_MIG_P22_SKIP_FULL_ERP_RESTORE=1`; source License `migrated_source_archived`; runtime suspend Option B with host retained; backups/certs/DNS snapshots retained; Phase 23 readiness reported without authorizing Phase 23; purge/delete/cert-revoke/host-terminate denied. Focused Phase 22 suites PASS; `tests/run_all.sh` PASS exit **0** (87 OK). Weight **1** credited → progress **98%** (97+1). Phase 23 **UNAUTHORIZED** (Offline bundles; purge NOT Phase 23). No live systems/data changed. No commit/push/deploy. Evidence: `docs/evidence/phase-22-source-archive-retirement/`.

## D113 — Phase 22 certification gap closure PASS (2026-08-04)

Closed PARTIAL certification gaps G1–G3 without redesign. G1: disposable PG 089 + schema upgrade + SaaS typecheck/lint/build/unit PASS. G2: actual Colima stop/start reboot matrix + archived-source persistence + auto-start prevention PASS. G3: real MinIO S3 + OpenSSH SFTP interruption, lost-ack replay, license/runtime response-loss PASS. Certification mode fail-closed on material skips/simulation/fixture archive. Regenerated installer still **`0.22.0-phase22`** SHA256 `dabd4ca5628afc7b6ffbe17796163779891bdf0f2ff70fb5698a55a2254879fb`. Authoritative `tests/phase22_authoritative_certification.sh`: SaaS exit 0 + `tests/run_all.sh` PASS (**104 OK**) → aggregate exit **0**. Weight **1** remains credited → progress **98%**. Phase 23 **UNAUTHORIZED**. No live systems/data changed. No commit/push/deploy. Evidence: `docs/evidence/phase-22-source-archive-retirement/` (CERTIFICATION_GAP_CLOSURE, AUTHORITATIVE_RUN_ALL, REAL_HOST_REBOOT_PROOF, S3/SFTP_INTERRUPTION_PROOF, etc.).

## D114 — Phase 23 scope review and correction (2026-08-05)

Verified canonical master-plan Phase 23 = **Offline bundles** (signed installer/image/entitlement/update/migration offline packages; air-gapped lab install+activate+update). Documented discrepancy: master objective is broader than updates alone; Phases 8/17 already cover install/activate foundations; Phase 15 `--offline-package` is explicitly minimum/not full Phase 23. Corrected product title: **Signed Offline Update Bundles, Air-Gapped Delivery, and Entitlement-Controlled Application**. Defined bundle format (tar.zst+OCI+Ed25519), entitlement interaction (`product_updates` + `offline_update_bundle`), License+env+Device targeting, signing/trust/replay/expiry/clock honesty, Registry export without embedding creds, Phase 15/16 reuse, result receipt + non-punitive reconciliation, conflict/security/egress models, owner decisions, implementation decomposition, and implementation-ready test plan. Proposed progress-accounting weight **1** (uncredited; remaining 2% for 23–25). Progress remains **98%**; installer **`0.22.0-phase22`** / SHA unchanged. Phase 23 **SCOPE REVIEW COMPLETE — IMPLEMENTATION NOT AUTHORIZED**. Phase 24 UNAUTHORIZED. Purge is not Phase 23. No runtime/`dist` changes. No bundle built/published. No live Registry/SaaS/customer changes. No commit/push/deploy. Evidence: `docs/evidence/phase-23-scope-review/`.

## D115 — Phase 23 implementation PARTIAL
Offline update bundles implemented (0.23.0-phase23); full certification gaps remain; progress stays 98%; Phase 24 unauthorized.

## D115b — Phase 23 certification PASS (2026-08-09)

Authoritative certification closed via ephemeral lifecycle: `tests/run_all.sh` PASS (113 OK / 0 FAIL), `phase23_authoritative_certification` aggregate exit **0**. Installer **`0.23.0-phase23`** SHA256 `b5267997825f995df7e5a1a137d1b5d8403971f278e8ad592ba90c88a84368bf`. Weight **1** credited → progress **99%**. Phase 24 remained UNAUTHORIZED until scope review. Evidence: `docs/evidence/phase-23-offline-update-bundles/`. No commit/push/deploy.

## D116 — Phase 24 scope review and correction (2026-08-09)

Verified canonical master-plan Phase 24 = **Security hardening** (remove unsigned self-update; key hashing; ticket replay; registry lockdown; secret scans CI; acceptance: security suite green; no service-role credentials in dist). Documented discrepancies: Phase 24 is **not** purge, production rollout, or final certification (Phase 25). Corrected product title: **Security Hardening — Signed-Update Enforcement, Secret Hygiene, Ticket-Replay Consolidation, Registry Lockdown, and Secret-Scan CI**. Inspected Phase 23 handoff (`READY FOR PHASE 24 — WARNING`, non-authorizing). Mapped certified ownership; classified debt D24-01…20; audited ODs; proposed progress weight **0.5** uncredited (with Phase 25 **0.5**) against remaining ~1% budget. Implementation **NOT AUTHORIZED**. Progress remains **99%**; installer/SHA unchanged. Phase 25 UNAUTHORIZED. No runtime/`dist` changes. No commit/push/deploy. Evidence: `docs/evidence/phase-24-scope-review/`.

## D117 — Phase 24 security hardening PASS (2026-08-10)

Implemented production-default signed-update enforcement; removed soft STRICT_SIG; quarantined fixture-token/fake-signature/unsigned-migration escapes behind disposable test-bypass triple; key fingerprint + private-key permission hygiene; ticket purpose-separation/replay adapters (no new engines); Registry ephemeral DOCKER_CONFIG cleanup asserts; secret-scan gate (`tools/secret_scan.sh`, embedded authoritative; Gitleaks preferred when installed); dist security scan; Phase 25 readiness report (informational). Installer **`0.24.0-phase24`** SHA256 `c0bb0e3e2130243387d58c11c153abd8506deaa9ecc77322cfbada077816b0b7`. `tests/run_all.sh` **160 OK / 0 FAIL**, exit **0**. Weight **0.5** credited → progress **99.5%**. Phase 25 UNAUTHORIZED. No commit/push/deploy/publish/live changes. Evidence: `docs/evidence/phase-24-security-hardening/`.

## D118 — Phase 25 scope review and correction (2026-08-10)

Verified canonical master-plan Phase 25 = **Final certification** (E2E certification matrix; docs sync; release checklist; acceptance: owner sign-off; evidence pack complete). Explicit note preserved: not purge; not automatic production rollout/publish. Corrected descriptive title: **Final Certification — E2E Matrix, Documentation Synchronization, Release Checklist, and Engineering Owner Sign-Off**. Separated ENGINEERING CERTIFIED vs READY TO RELEASE vs AUTHORIZED TO RELEASE vs RELEASED. Analyzed Phase 11.5 options A–D; recommended eng PASS with deferred visual + release-checklist gate (**OD-P25-01** required before 100% path). Recommended artifact Option A (certify exact `0.24.0-phase24` SHA). Defined provenance for dirty/uncommitted tree, real-runtime E2E matrix, docs-sync states, debt classes, and post-certification forbidden actions. Proposed progress weight **0.5** uncredited. Implementation **NOT AUTHORIZED**. Progress remains **99.5%**; installer/SHA unchanged. No runtime/`dist` changes. No commit/push/deploy/publish. Evidence: `docs/evidence/phase-25-scope-review/`.

## D119 — Inserted Security Platform Gate — architecture audit PASS (2026-08-10)

Inserted gate before Phase 25 Final Certification: **Security Platform Architecture Audit & Threat Model only**. Inspected `soviez-sh`, `Soviez ERP/soviez.sh` (byte-identical to `soviez-deploy/soviez.sh`), and modular stubs. Did **not** project external Odoo incident defects blindly; source-mapped Production ownership split (ERP monolith provisions PG+ERP Docker/Nginx/UFW; `soviez-sh` owns ops/update/migration/Phase-24 update security). Critical: C1 Odoo app role via `POSTGRES_USER=soviez` ⇒ image SUPERUSER semantics / COPY PROGRAM class (**UNSAFE**); C2 `docker -p HOST:8069` all-interfaces (**UNSAFE**); C3 missing fail-closed containment gate. Positives: no host-published PG; no `--link`/privileged/docker.sock; Python `secrets` RNG for DB/admin/app passwords; `list_db=False`. Designed Gates S1–S6, threat model, test plan, OD-SEC-01…12. Phase 24 history unchanged (signed-update scope ≠ platform containment). Phase 25 → **IMPLEMENTATION PAUSED PENDING SECURITY PLATFORM GATE**. Progress **99.5%** unchanged; installer **`0.24.0-phase24`** / SHA unchanged. No runtime hardening; no Phase 25 impl; no commit/push/deploy/publish/live changes. Evidence: `docs/evidence/security-platform-audit/`.

## D120 — Security Gate S1 Architecture & Critical Containment PASS (2026-08-10)

Implemented fail-closed critical containment: PostgreSQL bootstrap `soviez_admin` ≠ app `soviez_app` (NOSUPERUSER/NOCREATEDB/NOCREATEROLE/NOREPLICATION/NOBYPASSRLS; no dangerous predefined roles); COPY PROGRAM and server-file proofs; Odoo loopback publish `127.0.0.1:HOST:8069`; Docker baseline (no privileged/sock/host/--link); `proxy_mode=True` + `list_db=False`; weak-credential rejection; Stage/update/restore_test fixed `odoo`/`odoo` removed; dual-installer ERP/legacy aligned with canonical `src/security/platform/*`. Installer **`0.24.1-security-s1`** SHA256 `4b37198abd25cefa8c822b9b8195fc2adcbbbec47003d4508f23e70d39fa1a96`. Authoritative `tests/security/run_security_gate_s1.sh` PASS (incl. real Odoo 18 module install + nginx proxy). Phase 24 security suite PASS. Progress **99.5%** unchanged. Phase 25 remains **PAUSED PENDING S2–S6**. S2–S6 UNAUTHORIZED. No commit/push/deploy/publish/live changes. Evidence: `docs/evidence/security-gate-s1/`.

## D121 — Security Gate S2 authorized and implemented
Date: 2026-08-10
Authorize Host & Edge hardening (firewall, Nginx, edge modes, SSH staged, Fail2Ban, Webmin detect, host/persistence baselines).
**Result:** PASS — HOST & EDGE HARDENING COMPLETE (`0.24.2-security-s2`).
S3–S6 remain unauthorized. Phase 25 remains paused. Progress stays 99.5%.

## D122 — Security Gate S3 Compromise Detection PASS (2026-08-11)

Implemented read-only compromise detection: Odoo technical DB scanner (`--security-scan-db`), offline rules/IOC, technical baselines with rebaseline safety, custom addon static observation, host integrity (ld.so.preload/UID0/persistence drift; AIDE deferred), targeted YARA (+ fallback), multi-signal process/miner detection (no kill), network IOC observation via ss, local-only evidence with redaction/integrity/retention. Installer **`0.24.3-security-s3`**. Authoritative `tests/security/run_security_gate_s3.sh` PASS; real disposable PG Odoo-schema + Ubuntu 22.04/24.04 guest fixtures. ZATCA synthetic immutability proven. No destructive remediation. Progress **99.5%** unchanged. Phase 25 remains **PAUSED PENDING S4–S6**. S4–S6 UNAUTHORIZED. No commit/push/deploy/publish/live changes. Evidence: `docs/evidence/security-gate-s3/`.

## D123 — Security Gate S4 Migration & Restore Quarantine PASS (2026-08-11)

Implemented quarantine lifecycle, Docker internal egress deny, cron/mail/webhook/ZATCA containment, archive extraction safety, S3 pre-boot integration, explicit promote/reject/rollback, restore switch + migration cutover gates, fresh destination secrets, incident PRESERVE. Installer **`0.24.4-security-s4`** SHA256 `fdbf6ea35f5e318fd4b7ff737ecf2e0bed443629b12813c2f172456572072c25`. Authoritative `tests/security/run_security_gate_s4.sh` PASS. Progress **99.5%** unchanged. Phase 25 remains **PAUSED PENDING S5–S6**. S5–S6 UNAUTHORIZED. No commit/push/deploy/publish/live changes. Evidence: `docs/evidence/security-gate-s4/`.

## D124 — Security Gate S5 Update, Backup & Network Safety PASS (2026-08-11)

Implemented update safety baseline/semantic network validation, Docker restart matrix, Ubuntu 22.04/24.04 firewall reload + reboot survival, package policy (wait-only APT lock; legacy killall only in soviez-deploy), PDF/wkhtmltopdf smoke (synthetic PASS; inject FAIL; N/A on stock ubuntu:24.04), backup integrity/corruption/off-host MinIO disposable + SFTP classify, LOCAL_ONLY ≠ DR-capable, update engine hooks when `SOVIEZ_S5_ENFORCE=1` or non-test Production path. Installer **`0.24.5-security-s5`** SHA256 `d42791352b5825e6484c4ff8304d6e2249faf44b2b9082ed5233b96fa809cf42`. Authoritative focused `tests/security/run_security_gate_s5.sh` PASS (`SOVIEZ_S5_SKIP_NESTED_REGRESSIONS=1`). Progress **99.5%** unchanged. Phase 25 remains **PAUSED PENDING S6**. S6 UNAUTHORIZED. No commit/push/deploy/publish/live changes. Evidence: `docs/evidence/security-gate-s5/`.

## D125 — S5 Corrective Closure Package-Lock Safety PASS (2026-08-12)

Closed residual Case A dual Production wizard APT lock defect: replaced `heal_apt_locks` killall -9 apt/dpkg/unattended-upgrade + blind lock `rm` with wait-or-fail aligned to canonical `soviez_s5_apt_wait_for_lock` (`src/security/update_safety/apt_lock.sh`). ERP ↔ soviez-deploy remain supported and byte-identical safe; modular dist **`0.24.5.1-security-s5-corr1`** SHA256 `78092b384b28dc45a93801c5d0acad7d90e4ca3e41cd0b235419c2eeeb6531ca`. Corr suite PASS (unit + Ubuntu 22.04/24.04 guest no-kill proof). `tests/run_all.sh` may still be PENDING at evidence write. Progress **99.5%** unchanged. S6 **READY FOR OWNER AUTHORIZATION** but **NOT AUTHORIZED**. Phase 25 remains paused. No commit/push/deploy/publish/live customer changes. Evidence: `docs/evidence/security-s5-apt-lock-correction/`.


## D126 — Security Gate S6 Full Security Certification PASS (2026-08-12)

Certified exact artifact **`0.24.5.1-security-s5-corr1`** SHA256 `78092b384b28dc45a93801c5d0acad7d90e4ca3e41cd0b235419c2eeeb6531ca` (no VERSION bump; no product src changes required). Focused `SOVIEZ_S6_SKIP_NESTED_REGRESSIONS=1 bash tests/security/run_security_gate_s6.sh` **PASS** (installer parity ERP↔deploy + apt-lock safe; TEST-SEC-001..024; real PDF wkhtmltopdf 0.12.6.1 → `%PDF-` with inject FAIL; restore depth; telemetry egress audit; evidence integrity; OSS stack; adversarial matrix; E2E chain). LOCAL_ONLY ≠ DR; off-host MinIO/SFTP classified. Security Platform **CERTIFIED**. Progress **99.5%** at S6 completion. Release **NOT AUTHORIZED**. No commit/push/deploy/publish/live changes. Evidence: `docs/evidence/security-gate-s6/`.

## D127 — Phase 25 Final Certification PASS (2026-08-12)

Authorized engineering-only final certification on exact artifact **`0.24.5.1-security-s5-corr1`** SHA256 `78092b384b28dc45a93801c5d0acad7d90e4ca3e41cd0b235419c2eeeb6531ca` (unchanged). Orchestrated `tests/final_certification/*` + material E2E matrix (P25-E2E-01..12) + SaaS backend suites (typecheck/lint/commercial/device/slot/registry/support/stage; Phase 11.5 contract-only — visual deferred) + docs sync + release checklist + evidence integrity. Fresh final `tests/run_all.sh`: **217 OK / 0 FAIL**, exit **0**, ~3345 s authoritative duration. Engineering progress **100%**. Phase 11.5 visual **DEFERRED** (OD-P25-01). Release readiness **READY_WITH_OWNER_DECISIONS**; release authorization **NOT AUTHORIZED**; artifact publication / production rollout / source purge **NOT AUTHORIZED**. Owner engineering sign-off **PENDING_FINAL_RESULT_ACK**. OD-RELEASE-OFFHOST-BACKUP **PENDING**. No commit/push/deploy/publish/live customer changes. Evidence: `docs/evidence/phase-25-final-certification/`.

## D128 — Official Documentation Canonicalization PASS (2026-08-12)

Rebuilt `docs/` as canonical Source of Truth from code/tests/evidence (not stale plans). Families: `docs/user/`, `docs/dev/`, `docs/ai/` + portal `docs/README.md`. Source-audited CLI (~189 commands), ports, WebSocket/longpolling (ERP `/websocket`→8069; S2 also `/longpolling` same upstream; no public 8072), Stage 14/60, LOCAL_ONLY≠DR, `--merge-in` NOT_SUPPORTED, `--init` wizard-only, Webmin never-install, sovereignty invariants. Coverage matrix gaps unexplained = 0. Current-behavior conflicts = 0. Artifact SHA unchanged `78092b…`. Runtime product changes **NONE**. Engineering remains **100%**; Security **CERTIFIED**; Release **NOT AUTHORIZED**. Evidence: `docs/evidence/documentation-canonicalization/`. Validator: `tools/docs_validate.sh`.

## D129 — Post-Certification Discrepancy Closure PASS (2026-08-12)

Closed documentation-discovered discrepancies without inventing Phase 26:

- **D1 `--merge-in`:** Case B — intentionally never implemented; superseded by `--migration-*`. NOT_SUPPORTED. No alias. Static tests prevent advertising as supported.
- **D2 WebSocket:** Canonical topology workers=0 / proxy_mode=True / `/websocket`→8069 loopback = SUPPORTED_AND_CERTIFIED. workers>0 and gevent publish = NOT_SUPPORTED. Dual wizard formworkers forces Odoo workers=0 while retaining memory/cgroup sizing.
- **D3 Stage proxy_mode:** RUNTIME_DEFECT fixed — `ensure_stage_soviez_conf` now writes `proxy_mode = True` (ERP≡deploy).
- **D4 P21 8069:** Resolved upstream via `SOVIEZ_MIG_P21_UPSTREAM` / `SOVIEZ_HOST_PORT` / docker publish / fallback `127.0.0.1:8069`; added WS/longpoll locations.
- **D5 Phase-12 template:** SUPPORTED_RUNTIME via SSL promote — upgraded to `phase12-ws1` with WS/longpoll/Upgrade.

Installer **`0.24.5.2-postcert-corr1`**. Evidence: `docs/evidence/post-cert-discrepancy-closure/`. Release remains NOT AUTHORIZED.

## D130 — Registry Gateway installable + artifact 0.24.5.3-registry-gateway

- Registry Gateway: IMPLEMENTED / INSTALLABLE / TESTED
- Canonical publish path: `services/registry-gateway/` in Soviez/soviez-deploy
- Local ops: `soviez-registry-gateway/`
- Artifact: `0.24.5.3-registry-gateway` / `68ab59972d84d34f38c43862ca28946d3df3da5707fefa970230bd43e1da3460`
- Commercial Production Release: NOT AUTHORIZED

## D131 — Public deploy repository boundary correction

- **Policy:** `Soviez/soviez-deploy` = client-side lifecycle repository only
- **Removed from public main:** `services/registry-gateway/` (Gateway **server** package)
- **Retained public:** client Registry consumer (`src/registry/`, `src/api/registry_client.sh`) + customer-facing Registry docs/protocol
- **Canonical Gateway source:** local `soviez-registry-gateway/` (no private Git remote yet; no byte-sync into public deploy)
- **AI invariant:** never publish internal server-side services into `soviez-deploy`
- Artifact bytes unchanged: `0.24.5.3-registry-gateway` / `68ab59972d84d34f38c43862ca28946d3df3da5707fefa970230bd43e1da3460`
- Evidence: `docs/evidence/public-deploy-boundary-correction/`
- Commercial Production Release: NOT AUTHORIZED; Gateway not deployed by this correction
