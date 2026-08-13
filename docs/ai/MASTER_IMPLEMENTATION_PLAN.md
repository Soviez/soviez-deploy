# Master Implementation Plan — soviez-sh

**Status:** Planned (code-grounded). **Implementation not authorized** until owner opens a phase.  
**Baselines:** See `PROJECT_STATE.md`.  
**Constitution:** `PRODUCT_CONSTITUTION.md` (binding).  
**Discovery:** `CODE_GROUNDED_IMPLEMENTATION_DISCOVERY.md`.

Each phase below is a separately executable unit. Do not combine phases without owner approval.

---

## Global non-goals (all phases)

- Commit/push/deploy/publish without owner authorization.
- Continuous phone-home or business-data egress.
- Stripe-only entitlement design.
- Editing generated `dist/soviez.sh` as source.
- Breaking manual activation or migration-token invariants.

---

## Phase 1 — Repository foundation

| Field | Content |
|-------|---------|
| Objective | Establish `/soviez-sh` as canonical source home with layout, README, empty src/dist/tests. |
| Scope | Directories, README, ignore rules (planned), no operational installer. |
| Non-goals | Modular extraction of legacy script. |
| Repos | `soviez-sh` |
| Files | `README.md`, `src/**`, `dist/`, `tests/`, `schemas/`, `scripts/`, `ops/` |
| Migrations | None |
| APIs | None |
| Docs | README, PROJECT_STATE |
| Tests | Layout presence checks |
| Acceptance | Layout exists; legacy untouched; constitution linked |
| Rollback | Delete new empty dirs |
| Evidence | Directory listing |
| Complexity | Low |
| Dependencies | None |
| Owner approval before impl | **Done this task (scaffold only)** |
| Status | **Complete (scaffold)** |

---

## Phase 2 — Product constitution and documentation governance

| Field | Content |
|-------|---------|
| Objective | Binding constitution + AI/user/dev doc trees + discovery + master plan + PROJECT_STATE weights. |
| Scope | All docs listed in mission; labels Existing/Planned/Missing. |
| Non-goals | Product code. |
| Repos | `soviez-sh` |
| Files | `PRODUCT_CONSTITUTION.md`, `PROJECT_STATE.md`, `docs/**` |
| Acceptance | Constitution forbids list complete; weighted % documented; next phase named |
| Complexity | Medium |
| Owner approval | **Done this task** |
| Status | **Complete** |

---

## Phase 3 — Provider-neutral payment/commercial-grant model

| Field | Content |
|-------|---------|
| Objective | First-class provider + grant model without breaking `status='paid'` consumers. |
| Scope | Schema dual-write; admin grants without fake Stripe IDs (or parallel columns); adapters for Stripe fulfill + admin; docs. |
| Non-goals | New payment gateways live; installer changes; Stripe Dashboard product renames. |
| Repos | `soviez-saas` |
| Files expected | New migration(s); `admin-provisioning.ts`; `fulfill-checkout-session.ts`; types; admin audit |
| Migrations | Add `payment_provider`, `provider_reference`; optional `commercial_grants`; backfill `admin_provision` → `admin_grant`, Stripe → `stripe` |
| APIs | Admin grant APIs updated; internal grant resolver |
| Docs | `PAYMENT_PROVIDER_ABSTRACTION.md`, `COMMERCIAL_ENTITLEMENT_MODEL.md`, `PAYMENT_AND_GRANT_ABSTRACTION.md` |
| Unit | Grant create/revoke; provider enum |
| Integration | Admin grant creates paid slot without Stripe network |
| Failure | Duplicate grant; revoke mid-flight |
| Security | Service-role only writes; RLS deny client grant insert |
| Privacy | No business data in grant metadata |
| Backward-compat | `get_available_license_slots` still works via `paid` |
| Acceptance | Admin + Stripe paths both resolve via grant helper; no entitlement asks “is Stripe?” |
| Rollback | Feature flag dual-read; keep old columns |
| Evidence | `docs/evidence/phase-03-provider-neutral-commercial-model/` |
| Complexity | High |
| Dependencies | Phases 1–2 |
| Owner approval | **Authorized; delivered PARTIAL** then **PASS via consolidated hardening** (2026-07-30). Slot auth still legacy; dual-write + shadow parity. |
| Status | **PASS** |
| Evidence | `docs/evidence/phase-03-provider-neutral-commercial-model/` + `phase-03-04-consolidated-hardening/` |

---

## Phase 4 — Capability and entitlement model

| Field | Content |
|-------|---------|
| Objective | Capabilities: `technical_support`, `product_updates`, `stage_environments`, `is_installation_qualifying`. |
| Scope | Addon/capability metadata; new RPCs; **do not** extend `has_active_support_subscription*` for updates/stage. |
| Non-goals | Installer enforcement. |
| Repos | `soviez-saas` |
| Files | migrations; support-subscription libs; new entitlement server modules |
| Migrations | capabilities jsonb; annual seed; stage slug seed (inactive sales until phase 10) |
| APIs | Internal `has_capability(account, license_id, capability)` |
| Tests | Monthly ≠ product_updates; unbound denied for license-scoped caps |
| Acceptance | Cross-license denial tests green |
| Complexity | Medium-High |
| Dependencies | Phase 3 |
| Owner approval | **Authorized; delivered PARTIAL** then **PASS via consolidated hardening** (2026-07-30). Catalog+mappings+strict resolver; no auth cutover. |
| Status | **PASS** |
| Evidence | `docs/evidence/phase-04-capability-entitlement-foundation/` + `phase-03-04-consolidated-hardening/` |

---

## Phase 5 — Device authorization

| Field | Content |
|-------|---------|
| Objective | OAuth-device-style browser approve; server-bound device credential. |
| Scope | Tables `cli_devices`, device sessions, credentials, replay nonces; portal `/installer/authorize` + `/dashboard/devices`; APIs start/token/decision/devices; Ed25519 PoP signing. |
| Non-goals | Password in shell; commercial entitlement; installer runtime wiring. |
| Repos | `soviez-saas` (+ later installer client in phase 8+) |
| Acceptance | Approve/deny/expire/revoke; PoP; replay reject; RLS; Phase 3/4 regression green |
| Complexity | High (weight **6**) |
| Dependencies | Phase 3–4 PASS |
| Owner approval | **Authorized; delivered PASS** (2026-07-30) |
| Status | **PASS** |
| Evidence | `docs/evidence/phase-05-device-authorization/` |

---

## Phase 6 — License Slot reservation

| Field | Content |
|-------|---------|
| Objective | AVAILABLE→RESERVED→…→ACTIVATED lifecycle; concurrency-safe; Device PoP APIs. |
| Scope | `082` reservations/events/idempotency; soft-commit mint; installer slot APIs; portal visibility + manual claim bridge. |
| Non-goals | Installer wiring; auto ERP inject; private registry. |
| Repos | `soviez-saas` |
| Tests | Concurrent reserve; TTL; revoke; chain issue/ack; Phase 3–5 regression |
| Acceptance | No over-allocation; soft-commit; portal mint intact |
| Complexity | High (weight **5**) |
| Dependencies | Phases 3–5 |
| Owner approval | **Authorized; delivered PASS** (2026-07-30) |
| Status | **PASS** |
| Evidence | `docs/evidence/phase-06-license-slot-reservation/` |

---

## Phase 7 — Private registry — **PASS**

| Field | Content |
|-------|---------|
| Objective | Private image + pull sessions + digest manifests. |
| Scope | Migration `083`; SaaS `/api/installer/registry/*`; signed release manifests; Ed25519 pull tickets; internal Node gateway `soviez-registry-gateway/`; offline bundle foundation; CI prep workflow. |
| Non-goals | Installer wiring; live Hub cutover; full offline distribution (phase 23); `local_license_guard` changes. |
| Repos | `soviez-saas`, internal `soviez-registry-gateway/`, `Soviez ERP` prep workflow; public client in `soviez-deploy/src/registry/` |
| Tests | `test:phase7` (9), `test:phase7-db` (8), gateway (14); Phases 3–6 regression green |
| Acceptance | Digest-first catalog; Device PoP + `private_image_pull`; gateway streams OCI; no client Hub creds; ERP runtime independent |
| Complexity | High |
| Dependencies | Phase 5–6 |
| Evidence | `docs/evidence/phase-07-private-registry/FINAL_REPORT.md` |
| Weight | 6 → **31%** cumulative |

---

## Phase 8 — `--new` automatic/manual activation — **PARTIAL**

| Field | Content |
|-------|---------|
| Objective | Modular `--new` with consent; slot reserve; registry pull; tenant provision; ORM activate; manual path preserved. |
| Scope | `soviez-sh/src/**` (36 modules); `build/assemble.sh` → `dist/soviez.sh` v0.8.0-phase8; Phases 5–7 SaaS APIs consumed; `--reattach` resume. |
| Non-goals | `--init` activation; `local_license_guard` changes; live production E2E. |
| Repos | `soviez-sh` |
| Tests | 6 unit + 5 integration PASS; bash -n PASS; ShellCheck unavailable; guard fingerprint cert PASS |
| Acceptance | Auto path completes with ORM stub; manual ends `completed_activation_pending`; disconnect/resume; secrets not logged |
| **Gap** | Full disposable Odoo ERP container ORM E2E **not run** in certification environment |
| Complexity | High (weight **7**) |
| Dependencies | 5–7 PASS |
| Owner approval | **Authorized; delivered PARTIAL** (2026-07-30) |
| Status | **PARTIAL** — weight not awarded; cumulative **31%** |
| Evidence | `docs/evidence/phase-08-new-connected-activation/FINAL_REPORT.md` |
| Docs | `NEW_INSTANCE_CONNECTED_ACTIVATION_MODEL.md`, `NEW_COMMAND_PROTOCOL.md` |

---

## Phase 9 — Annual multi-year support

| Field | Content |
|-------|---------|
| Objective | Annual-only new sales; year discounts admin UI; early renew extend `max(valid_until,now)`; license_id required. |
| Scope | Prepaid checkout; discount table; coverage history; hide monthly new sales; refund/dispute hooks. |
| Non-goals | Break existing monthly renewals; installer `--update`; live migration apply. |
| Repos | `soviez-saas` |
| Acceptance | Tamper years/price fails; prepaid payment not subscription; monthly cannot buy new |
| Complexity | Medium-High |
| Dependencies | 3–4 |
| Owner approval | **Authorized; delivered PASS** (2026-07-30) |
| Status | **PASS** — weight 5 awarded; cumulative **43%** |
| Evidence | `docs/evidence/phase-09-annual-support-multi-year/FINAL_REPORT.md` |
| Docs | `ANNUAL_SUPPORT_MULTI_YEAR_MODEL.md`, `ANNUAL_SUPPORT_PROTOCOL.md`, user `ANNUAL_SUPPORT.md` |

---

## Phase 10 — Stage License add-on

| Field | Content |
|-------|---------|
| Objective | Monthly Stage SKU bound to `license_id`; entitlement API; no account fallback. |
| Scope | Catalog; checkout; `stage/check` API; admin grant path; portal coverage UX. |
| Non-goals | Multi-stage runtime (11). |
| Repos | `soviez-saas` |
| Acceptance | Cross-license Stage denial; gated vs local ops; Docker certification PASS |
| Complexity | Medium |
| Dependencies | 4–5 |
| Owner approval | **Done — PASS 2026-07-30** |
| Status | **Complete (PASS)** |

---

## Phase 10.5 — Stage commercial hardening

| Field | Content |
|-------|---------|
| Objective | Signed Stage Operation Tickets + private tooling verifier; commercial hardening without DRM claims. |
| Scope | Migration `086`; APIs authorize/consume/complete/status/revoke/offline/package; Node TS helper; threat model; origin cert; neutralization schema; digest-pinned `signed_package` tooling. |
| Non-goals | `--stage` wiring; Stage containers; domain/SSL runtime; retention worker; `local_license_guard` change; continuous phone-home; unbreakable DRM. |
| Repos | `soviez-saas`, `soviez-sh` |
| Signing | Domain **`soviez.stage-operation.v1`** (separate from Device Auth / License / release-manifest / registry pull / Migration HMAC / Stripe) |
| Bindings | license, device, host pubkey fp, production FP, DB UUID, stage ID, domain, release digest, tooling digest, arch, operation |
| Expiry | Ticket `exp` gates **START** only; never stops existing Stages |
| Privacy | `delivery_trace_id` + `subject_pseudonym` only — no business data |
| Docs | `STAGE_COMMERCIAL_ENFORCEMENT_THREAT_MODEL.md`, `STAGE_OPERATION_AUTHORIZATION_MODEL.md`, `STAGE_OPERATION_TICKET_PROTOCOL.md`, `STAGE_TOOLING_ARTIFACT.md` |
| Evidence | `docs/evidence/phase-10-5-stage-commercial-hardening/` |
| Acceptance | Ticket crypto + bindings + API contracts + helper verify/ledger/neutralize; RLS; honest Root residual documented; no Phase 11 leakage |
| Complexity | Medium-High (weight **4**) |
| Dependencies | 5, 7, 10 |
| Owner approval | **Authorized — PASS 2026-07-30** |
| Status | **PASS** (48% → **52%**; `48+4=52`) |

---

## Phase 11 — Multi-stage runtime

| Field | Content |
|-------|---------|
| Objective | Multiple Stage envs per license/tenant with parameterized names/networks/domains. |
| Scope | `/soviez-sh` stage modules; `--stage` CLI; inventory `/var/soviez/stages`; pg_dump snapshot; filestore clone; per-stage network `soviez-net-stage-<id>`; helper neutralization; trusted SSL; origin cert; connected+offline; lifecycle. |
| Non-goals | Retention auto-delete (13); `--update`; live deploy. |
| Repos | `soviez-sh` |
| Docs | `MULTI_STAGE_RUNTIME_MODEL.md`, `STAGE_RUNTIME_PROTOCOL.md`, `STAGE_NEUTRALIZATION_PROFILE.md`, `STAGE_ENVIRONMENTS.md` |
| Evidence | `docs/evidence/phase-11-multi-stage-runtime/` |
| Acceptance | A/B/C concurrent on dedicated networks; helper-required; expiry deny create / keep lifecycle; trusted SSL; Production filestore unchanged; **live disposable Postgres dump/restore**; **full offline import→create**; **disconnect/resume + disposable reboot recovery** |
| Complexity | High (weight **8**) |
| Dependencies | 10, **10.5** |
| Owner approval | **Authorized — PASS 2026-07-30** (initial PARTIAL closed same day) |
| Status | **PASS** (52% → **60%**; `52+8=60`) |
| VERSION | `0.11.0-phase11` |

---

## Phase 11.5 — SaaS UI/UX/PX Closure

| Field | Content |
|-------|---------|
| Objective | Complete Customer and Admin UX interfaces for all Phase 3-11 capabilities. |
| Scope | Customer IA (8 sections), Admin IA (7 sections), error recovery UX, legacy UI removal, preview environment |
| Customer IA | Dashboard, Licenses, Servers, Stages, Support, Billing, Operations, Security |
| Admin IA | Overview, Servers & Devices, License Slots, Annual Support, Stage License, Stage Operations, Releases |
| Repos | `soviez-saas` |
| Docs | `SAAS_CAPABILITY_UX_MODEL.md`, `SAAS_UI_COVERAGE_PROTOCOL.md` |
| Evidence | `docs/evidence/phase-11-5-saas-ux-closure/` |
| Acceptance | Complete customer/admin UX, error recovery flows, WCAG 2.1 AA accessibility, mobile responsive, RTL support, preview environment with demo credentials |
| Complexity | Medium-High (weight **5**) |
| Dependencies | 3, 4, 5, 6, 7, 8, 9, 10, 10.5, 11 |
| Owner approval | **Required** |
| Status | **FUNCTIONALLY CERTIFIED — VISUAL OWNER ACCEPTANCE DEFERRED** — SaaS functionally frozen; visual acceptance deferred; progress 60% until owner PASS; Phase 12 unauthorized until owner authorization |

---

## Phase 12 — Domain/SSL Lifecycle Hardening, Renewal, Recovery, and Production Policy

| Field | Content |
|-------|---------|
| Objective | Post-provision certificate lifecycle (expiry, renewal, rotation, rollback), durable DNS challenge retry/Abort, Nginx ownership/safe reload/recovery, local health/repair, and **owner-approved** Production domain/SSL policy — **not** a reimplementation of Phase 11 initial Stage domain/SSL provisioning. |
| Scope | Certificate lifecycle monitoring/renewal/rotation/rollback; DNS challenge lifecycle (signed verify, bounded wait, Try Again/Abort, resume, replay protection); Nginx ownership (`nginx -t`, atomic promote, rollback, collision/orphan reconciliation); local status/repair without mandatory SaaS; Production policy **only after** separate owner decisions. See `docs/ai/PHASE_12_SCOPE_CORRECTION.md`. |
| Explicit non-goals | Reimplement Phase 11 initial domain collection/uniqueness, initial trusted TLS issuance, self-signed rejection already certified, Stage creation, entitlement, Stage Operation Tickets, neutralization, Stage-origin cert redesign, retention, `--update`, backup/restore redesign, migration, automatic DNS-provider mutation, live deployment, SaaS commercial changes. |
| Phase 11 owns | Initial Stage domain collection; initial DNS validation; initial trusted SSL gate; Stage creation acceptance; Stage runtime isolation; Stage-origin certificate; initial Nginx Stage route creation. |
| Phase 12 owns | Post-provision cert lifecycle; renewal/rotation/expiry monitoring; repair/rollback; long-running DNS/SSL operational health; Production domain/SSL policy (when approved); removal of any remaining unsafe bypasses not already eliminated. |
| Repos | `soviez-sh` (primary); SaaS challenge verify API only if owner-authorized and needed for lifecycle |
| Docs | `PHASE_12_SCOPE_CORRECTION.md`, `DOMAIN_SSL_LIFECYCLE_MODEL.md`, evidence `docs/evidence/phase-12-domain-ssl-lifecycle/` |
| Acceptance | Renewal before expiry; renewal after transient failure; rollback after invalid replacement; DNS retry/Abort Safely; signed challenge binding + replay rejection; Nginx collision detection + unrelated hosts untouched; `nginx -t` + safe reload; reboot recovery; chain/hostname/expiry checks; local health without SaaS; no self-signed final acceptance; no unsafe `force` path; Production policy exactly as separately approved; no Phase 11 regression; isolated disposable evidence only |
| Complexity | Medium-High (weight **4**) |
| Dependencies | 11 (PASS); 11.5 visual acceptance not required for Phase 12 auth but SaaS remains frozen |
| Owner approval | **Required before implementation** (scope + Production policy questions in `OWNER_DECISIONS_REQUIRED.md`) |
| Status | **PASS — DOMAIN/SSL LIFECYCLE HARDENING COMPLETE** (2026-07-30); weight **4** credited; progress **64%** |
| Progress impact | `60 + 4 = 64%` |

---

## Phase 13 — Stage retention

| Field | Content |
|-------|---------|
| Objective | Default 14-calendar-day retention from immutable Stage creation, with a 60-calendar-day absolute maximum; warnings, Safe Shield auto-delete independent of entitlement. |
| Scope | Local Stage retention sidecar/registry; scheduler; final backup; Safe Shield; countdown disclosure; retry/reattach/tombstone. |
| Repos | `soviez-sh` |
| Acceptance | Expired entitlement keeps Stage; 14/60 total-lifetime semantics; verified final backup; retention expiry deletes only exact Stage resources with Safe Shield; ambiguity → Needs Action |
| Complexity | Medium |
| Dependencies | 11–12 |
| Owner approval | **Authorized — PASS 2026-07-30** |
| Status | **PASS — STAGE RETENTION COMPLETE**; weight **3** credited; `64 + 3 = 67%` |
| Evidence | `docs/evidence/phase-13-stage-retention/FINAL_REPORT.md` |

---

## Phase 14 — Unified Operation Engine Consolidation and Cross-Command Recovery

| Field | Content |
|-------|---------|
| Objective | Unify existing operation-engine implementations across installer commands into one consistent, auditable, cross-command engine (shared schema, registry, conflict locks, CLI, cancel/rollback, orphan/reboot reconciliation, logs/history, schema migration, scheduler coordination) with readiness for update/backup/migration — **not** first-time persistence/systemd/reattach. |
| Scope | Consolidation over Phases 8/11/12/13 engines; host-local registry; cross-command conflict matrix; unified `--operation-*` CLI with aliases; shared cancel/rollback; orphan reconciliation; log/redaction/history conventions; state-version migration; scheduler coordination. See `docs/ai/PHASE_14_SCOPE_CORRECTION.md`. |
| Repos | `soviez-sh` |
| Acceptance | Verified: all existing op types in one registry; no state loss; conflict matrix enforced; unified reattach/cancel; aliases compatible; orphan/reboot recovery; redacted logs; Phase 8/11/12/13 regressions green. Full reports in `docs/evidence/phase-14-unified-operation-engine/` and canonical sync closure reports in `docs/evidence/phase-14-canonical-sync-closure/`. |
| Complexity | High |
| Proposed weight | **5** (credited on PASS) |
| Dependencies | 8, 11, 12, 13 (capability foundations already PASS) |
| Owner approval | **Done** |
| Status | **PASS** (2026-07-31) |
| Progress impact | +5% (credited → 72%) |
| Explicit non-goals | Rebuild Phase 8/11/12/13 persistence/workers/schedulers from scratch; change entitlements/retention/SSL policy; implement update/backup/migration/offline; SaaS UI; live deploy |

---

## Phase 15 — Safe update

| Field | Content |
|-------|---------|
| Objective | Exact one Production tenant; annual product_updates; digest pull. |
| Scope | Replace all-tenant default; entitlement gate; candidate isolation; Phase 14 integration. |
| Repos | `soviez-sh` (SaaS reference only) |
| Acceptance | No-arg update refused; monthly fails; annual passes |
| Complexity | Medium → proposed weight **6** |
| Dependencies | 4, 7, 9, 14 |
| Owner approval | Required |
| Status | **PASS** (2026-07-31 final certification closure); weight **6** credited; progress **84%** (`72+6`); artifact `0.15.0-phase15`; evidence `docs/evidence/phase-15-final-certification-closure/` |

---

## Phase 16 — Production Backup, Restore, Verification, and Recovery Management

| Field | Content |
|-------|---------|
| Objective | Deliver a sovereign, ops-integrated **Production** Full backup + **candidate-first** same-host restore product with verification, retention, optional owner-controlled remote destinations, and encryption — without Soviez-hosted backup and without weakening License Guard. |
| Scope | Full backup unit (`pg_dump -Fc` + filestore + manifest); local destination required; optional S3-compatible/SFTP remote; encryption (remote mandatory; local default-on); candidate-first restore reusing Phase 15 patterns; LG temporary candidate identity (no new permanent slot); verification levels; retention 7/4/12 independent of Stage 14–60; scheduling 02:00 local; Phase 14 op types `production_backup`, `backup_verification`, `backup_restore_test`, `production_restore`, `backup_retention_cleanup`, `backup_export`, `backup_import`; conflict/capacity/security models; Stage live backup via shared `soviez_backup_stage_live_backup`. |
| Explicit exclusions | Incremental/WAL (deferred); cross-host restore (Phase 17/migration); Soviez-hosted backup / backup payload to SaaS; Odoo web `/web/database/backup\|restore`; filestore-only restore product; direct Production overwrite by default; treating Stage `--stage-backup`, Phase 13 retention archives, or Phase 15 recovery_set as the Production product; SaaS UI; live deploy. |
| Repos | `soviez-sh` (legacy `soviez-deploy` reference only; ERP/SaaS reference for exclusions) |
| Acceptance | Lab/fixture round-trip: Full backup → integrity verify → restore-test → same-host Production restore with 24h rollback window; encryption proofs; local/S3/SFTP destinations; retention/pin; no SaaS backup upload; cross-host deny |
| Complexity | Medium → weight **6** |
| Weight | **6** — **credited** |
| Dependencies | 11 (PG primitives), 14 (ops engine), 15 (candidate-first + LG temp identity); OD-01…OD-18 recorded (D097) |
| Owner approval | Implementation + final certification closure authorized |
| Status | **PASS** (2026-08-01); closure evidence `docs/evidence/phase-16-final-certification-closure/`; implementation evidence `docs/evidence/phase-16-production-backup-restore/`; scope review retained `docs/evidence/phase-16-scope-review/` |
| Progress impact | **84%** (78 + 6) |
| Installer | **`0.16.0-phase16`** |

### Phase 16 history note
Scope review (2026-08-01) recorded status **SCOPE REVIEW COMPLETE — IMPLEMENTATION NOT AUTHORIZED** with uncredited proposed weight 6 and installer `0.15.0-phase15`. Implementation followed as PARTIAL; final certification closure closed MinIO/SFTP/real restore-test/host-reboot gaps and credited weight 6.

---

## Phase 17 — Migration Discovery, Trust Pairing, and Destination Bootstrap

| Field | Content |
|-------|---------|
| Status | **PASS** (2026-08-01 final certification closure). Real Ubuntu 22.04/24.04 amd64 destination bootstrap, signed installer, mTLS, offline pairing, token non-consumption, Colima reboot matrix, multi-tenant isolation proven. Progress **89%** (84+5). Installer **`0.17.0-phase17`**. |
| Corrected title | Migration Discovery, Trust Pairing, and Destination Bootstrap |
| Objective | Exact-source discovery; destination bootstrap with signed installer + temporary identity; trust pairing; migration-pair object; readiness report. No payload transfer; source active; Migration Token not consumed; destination not activated as Production. |
| Non-goals | Streaming; DNS/maintenance landing; token burn; dest Production activate; source purge (Phases 18–22). |
| Repos | `soviez-sh` |
| Acceptance (post full PASS) | SOURCE DISCOVERY COMPLETE; DESTINATION BOOTSTRAP COMPLETE; MIGRATION PAIR TRUSTED; READINESS PASS/WARNING/BLOCKED; NO DATA TRANSFER; SOURCE ACTIVE; TOKEN NOT CONSUMED; DEST PRODUCTION NOT ACTIVATED |
| Complexity | High |
| Dependencies | 5–8, 11–16 foundations; especially 7, 14 |
| Weight | **5** (credited) |
| Owner approval | Binding ODs applied in implementation (see D100); final closure D101 |
| Evidence | `docs/evidence/phase-17-migration-discovery-bootstrap/` + `docs/evidence/phase-17-final-certification-closure/` + prior scope review |

---

## Phase 18 — Maintenance Landing, Signed Domain Validation, and Migration Routing Readiness

| Field | Content |
|-------|---------|
| Status | **PASS** (2026-08-02). Progress **93%** (89+4). Installer **`0.18.0-phase18`**. |
| Older title | Destination maintenance landing and signed DNS validation |
| Corrected title | Maintenance Landing, Signed Domain Validation, and Migration Routing Readiness |
| Objective | Domain plan; signed DNS ownership + reachability; neutral destination maintenance landing; migration-subdomain TLS; routing-plan readiness — without payload transfer, Production cutover, token burn, or destination Production activation. |
| Non-goals | Streaming (19); token burn / License rebind (20); Production traffic cutover / source maintenance cutover (21); source purge (22). |
| Repos | `soviez-sh` (reuse Phase 12 SSL + Phase 17 pair) |
| Acceptance | Banner: MIGRATION PAIR VALID; DOMAIN PLAN COMPLETE; DNS CHALLENGE VERIFIED; DESTINATION LANDING READY; TLS VALID; ROUTING PLAN READY; SOURCE TRAFFIC UNCHANGED; NO BUSINESS DATA TRANSFERRED; TOKEN NOT RESERVED/CONSUMED; DEST ERP PRODUCTION NOT ACTIVATED |
| Complexity | Medium-High |
| Dependencies | 12, 14, 17 |
| Weight | **4** (credited) |
| Owner approval | Defaults applied (migrate subdomain; manual DNS; 30m challenge; 24h readiness; Abort preserves owner DNS) |
| Evidence | `docs/evidence/phase-18-scope-review/` + `docs/evidence/phase-18-migration-domain-routing/` |

---

## Phase 19 — Direct Streaming Migration, Resumable Transfer, and Destination Staging

| Field | Content |
|-------|---------|
| Status | **PASS** (2026-08-02 certification gap closure). Progress **95%** (93+2). Installer **`0.19.0-phase19`**. |
| Older title | Streaming migration |
| Corrected title | **Direct Streaming Migration, Resumable Transfer, and Destination Staging** |
| Objective | Direct source→destination encrypted payload transfer (DB/filestore/addons/config/selected Stages) into isolated non-Production staging; resumable chunks; stop before token burn, License rebind, Production activation, or traffic cutover. |
| Strategy | Option B — multi-pass pre-sync + short final write freeze; Phase 16 `-Fc` final DB; file-level filestore chunks; **no WAL/PITR** |
| Repos | `soviez-sh` (refs: SaaS token APIs Phase 20, ERP License Guard Phase 20) |
| Certification | Real mTLS E2E, real PG dump/restore, real ERP staging, application write-freeze, Stage selection, Colima reboot, network/failure/adversary matrices, clean `tests/run_all.sh` PASS |
| Weight | **2** credited |
| Dependencies | 16–18, 14 |
| Evidence | `docs/evidence/phase-19-scope-review/` + `docs/evidence/phase-19-direct-streaming-migration/` |
| Next | Phase 20 **PASS** (see below) |

---

## Phase 20 — Atomic Migration Authorization, Token Consumption, License Rebind, and Destination Activation

| Field | Content |
|-------|---------|
| Status | **PASS** (2026-08-03). Progress **96%** (95+1). Installer **`0.20.0-phase20`**. SHA256 `4e4eafc9ebb1fe8db62b789faead89476b03455536e5c1cd33e6c470963288d9`. |
| Older title | Existing migration-token integration / Atomic Migration Token Consumption, License Rebind, and Destination Production Activation |
| Corrected title | **Atomic Migration Authorization, Token Consumption, License Rebind, and Destination Activation** |
| Objective | After Phase 19 verified staging: atomic SaaS commit of Migration Token consume + destination Production binding + source `migration_origin_grace`; local apply to `production_licensed_pre_cutover` (non-public); Stage rebind; anti-split-brain; Phase 21 readiness report — **stop before DNS/traffic cutover**. |
| Authoritative SoR | SaaS `commit_migration_authorization` (`087`); installer certification mirror SQLite ledger |
| Token lifecycle | No long-lived reservation; consume IFF authorization committed |
| Repos | `soviez-sh`, `soviez-saas` (UI frozen), `Soviez ERP` License Guard |
| Certification | Focused Phase 20 suites PASS; disposable PG commit proof PASS; SaaS typecheck/lint/build PASS; `tests/run_all.sh` PASS exit 0 (77 OK) |
| Weight | **1** credited |
| Dependencies | 19, 4 (entitlements), 8 (activation patterns), 17–18 |
| Evidence | `docs/evidence/phase-20-scope-review/` + `docs/evidence/phase-20-atomic-authorization-rebind/` |
| Next | Phase 21 **UNAUTHORIZED** |

---

## Phase 21 — Production Traffic Cutover, DNS Transition, Health Validation, and Immediate Rollback

| Field | Content |
|-------|---------|
| Status | **PASS** (2026-08-03). Progress **97%** (96+1). Installer **`0.21.0-phase21`**. SHA256 `b95203dbb6073362cc1215272e6e837ee75cc366f78ac2c7d09150a554ec462d`. |
| Older title | Traffic ownership transfer / Production cutover |
| Corrected title | **Production Traffic Cutover, DNS Transition, Health Validation, and Immediate Rollback** |
| Objective | Controlled transition of customer traffic from source Production to already licensed, internally verified destination Production: final sync, source maintenance, Production-domain TLS, DNS/nginx transition, traffic-owner switch, health/smoke, immediate rollback window — **stop before source archive/purge (Phase 22)**. |
| Strategy | Option C hybrid — dest Production route → TLS → DNS → source maintenance during propagation → public health PASS → `traffic_owner=destination`; no SaaS traffic relay |
| Certification | Focused Phase 21 suites PASS; real disposable authoritative DNS dig quorum; local-CA TLS chain; `tests/run_all.sh` PASS exit 0 (82 OK) |
| Weight | **1** credited |
| Dependencies | 20, 18, 19, 16, 12 |
| Evidence | `docs/evidence/phase-21-scope-review/` + `docs/evidence/phase-21-production-cutover/` |
| Next | Phase 22 = PASS; Phase 23 UNAUTHORIZED |

---

## Phase 22 — Rollback Window Closure, Source Archive, License Finalization, and Safe Retirement Readiness

| Field | Content |
|-------|---------|
| Prior title (superseded) | Source retention/archive/purge |
| Corrected title | **Rollback Window Closure, Source Archive, License Finalization, and Safe Retirement Readiness** |
| Corrected objective | After Phase 21 cutover: stabilize destination; close rollback window (eligibility + owner confirm, not time-only); create/verify reversible source archive; finalize source License to non-Production archived state; suspend source runtime per policy; retain backups/certs/DNS evidence; produce retirement + Phase 23 readiness — **stop before purge**. |
| Explicit exclusions | Source purge; disk/volume/host wipe; backup deletion; certificate revocation; DNS rollback-history deletion; automatic time-only cleanup; reverse-migration product; Phase 23–25 behavior. |
| Archive vs purge | **ARCHIVE** = reversible, verified, encrypted, operation-bound. **PURGE** = irreversible destruction — forbidden in Phase 22; future purge requires separate owner authorization and must not silently become Phase 23 (master-plan Phase 23 = Offline bundles). |
| Repos | `soviez-sh` (SaaS metadata RPCs only if later authorized; no business payload) |
| Status | **PASS** (2026-08-04). Progress **98%** (97+1). Installer **`0.22.0-phase22`**. SHA256 `b8df40b6a2e3fa4a15b16953812f74c789b2396a9dbaad4bf4c6e9e57408d274`. |
| Certification | Focused Phase 22 unit/static/e2e/stabilization/reboot suites PASS; real PG dump/restore (docker `postgres:16-alpine`); filestore verify PASS; full ERP restore WARNING/skipped (`SOVIEZ_MIG_P22_SKIP_FULL_ERP_RESTORE=1`); no purge/delete/cert-revoke/host-terminate; `tests/run_all.sh` PASS exit 0 (**87 OK**) |
| Weight | **1** credited |
| Dependencies | 21, 20, 16, 13 |
| Evidence | `docs/evidence/phase-22-scope-review/` + `docs/evidence/phase-22-source-archive-retirement/` |
| Next | Phase 23 scope review COMPLETE — implementation NOT authorized; purge ownership remains separate / OPEN |

---

## Phase 23 — Offline bundles

| Field | Content |
|-------|---------|
| Prior short title | Offline bundles |
| Corrected title (scope review) | **Signed Offline Update Bundles, Air-Gapped Delivery, and Entitlement-Controlled Application** |
| Objective (canonical) | Signed installer/image/entitlement/update/migration offline packages. |
| Corrected product focus | First-class offline **update** delivery: entitlement-gated issuance, signed full bundles, Registry export on connected worker, air-gapped verify/apply via Phase 15, mandatory Phase 16 backup, signed result receipt, later reconciliation — no phone-home / no Registry creds in bundle / no business-data egress. |
| Explicit exclusions | Purge/host wipe; App Store; business-data export; permanent Docker login; forced startup subscription checks; remote unattended update; Phase 24–25; emergency recovery-bundle unless separately authorized. |
| Repos | `soviez-sh`, `soviez-saas`, CI |
| Acceptance | Air-gapped lab install+activate+update path (install/activate foundations already in Phases 8/17; Phase 23 closes full update-bundle product) |
| Complexity | High |
| Dependencies | 7, 8, 15 (also reuses 4, 16, 14 patterns) |
| Owner approval | Required |
| Progress weight | **Not assigned** in original plan; remaining budget **2%** for Phases 23–25. Proposed progress-accounting weight **1** (uncredited until implementation PASS). |
| Status | **SCOPE REVIEW COMPLETE — IMPLEMENTATION NOT AUTHORIZED** (2026-08-05). Progress remains **98%**. Installer **`0.22.0-phase22`** unchanged. |
| Evidence | `docs/evidence/phase-23-scope-review/` |

---

## Phase 24 — Security hardening

| Field | Content |
|-------|---------|
| Prior short title | Security hardening |
| Corrected title (scope review) | **Security Hardening — Signed-Update Enforcement, Secret Hygiene, Ticket-Replay Consolidation, Registry Lockdown, and Secret-Scan CI** |
| Objective (canonical) | Remove unsigned self-update; key hashing; ticket replay; registry lockdown; secret scans CI. |
| Explicit exclusions | Purge/host wipe; production rollout/public publish; Phase 25 final certification matrix/owner release sign-off; new update/backup/migration/offline-bundle engines; frozen SaaS UI; App Store; business-data egress; permanent Docker login. |
| Repos | all (primarily `soviez-sh`; SaaS only if server-side secret hygiene requires it — UI frozen) |
| Acceptance | Security test suite green; no service-role **credentials** in dist script; secret-scan CI green |
| Complexity | Medium-High |
| Dependencies | Prior phases (esp. 7, 10.5, 15, 23) |
| Owner approval | Required |
| Progress weight | **0.5** (credited → progress **99.5%**). |
| Status | **PASS — SECURITY HARDENING COMPLETE** (2026-08-10). Installer **`0.24.0-phase24`**. SHA256 `c0bb0e3e2130243387d58c11c153abd8506deaa9ecc77322cfbada077816b0b7`. Phase 25 remains **UNAUTHORIZED**. |
| Evidence | `docs/evidence/phase-24-scope-review/` + `docs/evidence/phase-24-security-hardening/` |

---

## Phase 25 — Final certification

| Field | Content |
|-------|---------|
| Prior short title | Final certification |
| Corrected title (scope review) | **Final Certification — E2E Matrix, Documentation Synchronization, Release Checklist, and Engineering Owner Sign-Off** |
| Objective (canonical) | End-to-end certification matrix; docs sync; release checklist. |
| Acceptance | Owner sign-off (engineering certification acceptance); evidence pack complete. Release authorization is **separate**. |
| Explicit exclusions | Purge/host wipe; automatic production rollout; public artifact publish; live DNS/commercial mutation; new engines; frozen SaaS UI redesign; conflating ENGINEERING CERTIFIED with AUTHORIZED TO RELEASE. |
| Repos | all (certification orchestration primarily `soviez-sh`; SaaS backend revalidation; UI frozen) |
| Complexity | Medium |
| Dependencies | 1–24 |
| Owner approval | Required before implementation |
| Progress weight | **0.5** proposed (uncredited until implementation PASS). Remaining budget **0.5%**. |
| Status | **PASS — FINAL CERTIFICATION COMPLETE** (2026-08-12). Exact artifact **`0.24.5.1-security-s5-corr1`** SHA256 `78092b384b28dc45a93801c5d0acad7d90e4ca3e41cd0b235419c2eeeb6531ca`. Engineering progress **100%**. Release authorization **NOT AUTHORIZED**. Evidence: `docs/evidence/phase-25-final-certification/`. Decision **D127**. |
| Explicit note | Not purge; not automatic production rollout/publish. Phase 11.5 visual owner acceptance deferred (OD-P25-01). |
| Evidence | `docs/evidence/phase-25-scope-review/` (scope); gate audit `docs/evidence/security-platform-audit/` |
| Phase 11.5 | Visual acceptance treatment requires **OD-P25-01**; recommended: eng PASS allowed while deferred; release checklist gate for visual. |
| Artifact model (recommended) | Option A — certify exact Phase 24 artifact unless packaging-only Option B is chosen at implementation auth. |

---

## Inserted Security Platform Gate (before Phase 25 Final Certification)

| Field | Content |
|-------|---------|
| Title | **Security Platform Architecture Audit & Threat Model** |
| Nature | Inserted gate — **docs/audit only** in this mission; implementation of Gates S1–S6 separately authorized |
| Objective | Inventory architecture; audit PG privilege/network, Odoo exposure, Docker, firewall, secrets, migration quarantine, ZATCA safety, update/network, OS/SSH/Webmin/edge/backup/FIM; threat model; target architecture; test plan; operator decisions |
| Status | **AUDIT COMPLETE — IMPLEMENTATION NOT AUTHORIZED** (2026-08-10); **S1 implementation PASS** (2026-08-10) — see Security Gate S1 section |
| Progress impact | **None** — remains **99.5%**; does not falsify Phase 24 PASS |
| Phase 24 clarification | Phase 24 = signed-update/secret-scan hardening — **not** host/DB containment |
| Critical defects (source-proven) | C1–C3 addressed in Security Gate S1 |
| Evidence | `docs/evidence/security-platform-audit/` (audit); `docs/evidence/security-gate-s1/` (implementation) |
| Next | Owner may authorize **Security Gate S2**. Phase 25 remains paused per OD-SEC-10 |

---

## Security Gate S1 — Architecture & Critical Containment

| Field | Content |
|-------|---------|
| Title | **Architecture & Critical Containment** |
| Status | **PASS — ARCHITECTURE & CRITICAL CONTAINMENT COMPLETE** (2026-08-10) |
| Installer | **`0.24.1-security-s1`** |
| SHA256 | `4b37198abd25cefa8c822b9b8195fc2adcbbbec47003d4508f23e70d39fa1a96` |
| Progress | **99.5%** unchanged (no credit) |
| Closed | C1 PG least privilege; C2 loopback Odoo publish; C3 fail-closed gate; Stage weak creds |
| Evidence | `docs/evidence/security-gate-s1/` |
| S2–S6 | **UNAUTHORIZED** |
| Phase 25 | Remains **PAUSED PENDING S2–S6** |

---

## Suggested next owner prompt

Authorize **Security Gate S2 (Host & Edge Hardening)** after reviewing `docs/evidence/security-gate-s1/`. Do **not** resume Phase 25 until OD-SEC-10. Do not publish or roll out.


S2 status: IN PROGRESS (this mission).


## Security Gate S2 status
PASS — HOST & EDGE HARDENING COMPLETE (0.24.2-security-s2). Progress 99.5%.

## Security Gate S3 status
PASS — COMPROMISE DETECTION COMPLETE (0.24.3-security-s3). S4–S6 unauthorized. Phase 25 paused pending S4–S6. Progress 99.5%.

## Security Gate S4 status
PASS — MIGRATION & RESTORE QUARANTINE COMPLETE (0.24.4-security-s4). S5–S6 unauthorized. Phase 25 paused pending S5–S6. Progress 99.5%.

## Security Gate S5 status
PASS — UPDATE, BACKUP & NETWORK SAFETY COMPLETE (0.24.5-security-s5). S6 unauthorized. Phase 25 paused pending S6. Progress 99.5%. Focused run_security_gate_s5.sh PASS; run_all may still be pending authoritative completion at evidence write.

## S5 Corrective Closure status
PASS — PACKAGE-LOCK SAFETY / APT WAIT-OR-FAIL (0.24.5.1-security-s5-corr1, SHA256 78092b384b28dc45a93801c5d0acad7d90e4ca3e41cd0b235419c2eeeb6531ca). Dual wizard heal_apt_locks remediated (Case A). Corr suite PASS; run_all may still be PENDING. S6 READY FOR OWNER AUTHORIZATION but NOT authorized. Phase 25 paused. Progress 99.5%. Evidence: docs/evidence/security-s5-apt-lock-correction/. Decision D125.

## Security Gate S6 status
PASS — FULL SECURITY CERTIFICATION COMPLETE (exact artifact 0.24.5.1-security-s5-corr1, SHA256 78092b384b28dc45a93801c5d0acad7d90e4ca3e41cd0b235419c2eeeb6531ca). Security Platform CERTIFIED. Evidence: docs/evidence/security-gate-s6/. Decision D126.

### Phase 25 — Final Certification (2026-08-12)

PASS — FINAL CERTIFICATION COMPLETE. Engineering progress 100%. Fresh tests/run_all.sh 217 OK / 0 FAIL exit 0. Release NOT AUTHORIZED. Phase 11.5 visual DEFERRED. Evidence: docs/evidence/phase-25-final-certification/. Decision D127.
