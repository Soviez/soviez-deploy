# Sovereignty First (deep dive)

## Confirmed decision
See PRODUCT_CONSTITUTION.md §§2–6, 15–16.

## Existing good behavior
- ERP verifies licenses offline (LICENSE_FLOW.md / local_license_guard).
- Legacy installer does not upload dumps to SaaS.
- **Device authorization (Phase 5):** browser-assisted, minimal metadata, no phone-home, revoke ≠ stop ERP. See `DEVICE_AUTHORIZATION_MODEL.md`.

## Planned
- Pre-flight disclosure UI for every connected call (device auth portal disclosure shipped; installer terminal disclosure later).
- Offline bundles parity.
- Migration streams customer-controlled only.

## Forbidden
Hidden telemetry; continuous phone-home; SaaS as DB/filestore proxy.
Device private keys in SaaS; service-role in installer; passwords in the terminal.

## Phase 7 — Private registry (implemented foundation)

- **Pull is optional:** running ERP never depends on registry or SaaS availability.
- **No client Hub tokens:** Docker Hub pull-only secrets exist in gateway env only; customers receive short-lived pull tickets.
- **Digest authority:** `:latest` is not signing or authorization authority; immutable `sha256:…` only.
- **Temp docker config:** installer contract uses isolated `--config` directory, deleted after pull.
- **No blob proxy through Vercel:** multi-GB OCI streaming uses dedicated Node gateway — SaaS issues tickets only.
- See `PRIVATE_REGISTRY_AND_PULL_AUTHORIZATION_MODEL.md`.

## Phase 8 — New connected activation (implemented foundation — PARTIAL)

- **`--new` only:** automatic activation on new instance creation, not `--init` (D003).
- **Explicit consent:** connection disclosure before first SaaS call; no hidden phone-home.
- **Activation key sovereignty:** key never in argv, shell history, or logs; staged via stdin→0600 file inside container; official ORM method only.
- **Manual path preserved:** user may defer activation; operation ends `completed_activation_pending`.
- **Disconnect/resume:** `--reattach` continues from persisted state; running partial ops recoverable.
- **Guard untouched:** `local_license_guard` not modified; fingerprint format certified read-only.
- **Certification gap:** full disposable Odoo ERP container ORM E2E not run in certification environment.
- See `NEW_INSTANCE_CONNECTED_ACTIVATION_MODEL.md`.

## Phase 9 — Annual Support runtime independence (implemented)

- **Optional coverage:** Annual Technical Support is commercial entitlement, not a runtime dependency.
- **No phone-home:** running ERP does not continuously report support status to SaaS.
- **Expiration scope:** ends technical support + product update entitlement only — does **not** deactivate ERP, block login, remove data, or block backup/restore.
- **Update gate deferred:** installer `--update` will consume coverage/entitlement APIs in a later phase; not wired in Phase 9.
- See `ANNUAL_SUPPORT_MULTI_YEAR_MODEL.md`, user `docs/user/SUPPORT_EXPIRATION.md`.

## Phase 10 — Stage License (implemented)

- **Optional entitlement:** Stage License gates new create/clone/refresh/rebuild commercially.
- **Expiration ≠ stop:** existing Stages are not stopped or deleted when entitlement ends.
- See `STAGE_LICENSE_COMMERCIAL_MODEL.md`.

## Phase 10.5 — Stage commercial hardening (PASS)

- **Operation authorization:** gated Stage ops require Stage Operation Tickets (`soviez.stage-operation.v1`).
- **START-only expiry:** ticket `exp` does not stop running Stages; Stage License expiry still does not stop/delete Stages.
- **Offline-capable after creation:** once authorized/created, Stage continues without continuous SaaS contact.
- **Minimal metadata:** tickets carry licensing/device/host/fingerprint/digest bindings plus `delivery_trace_id` and `subject_pseudonym` (license hash) — **no** name, email, or business data.
- **Origin certificate:** local evidence only; no phone-home; survives entitlement expiry.
- **Domain/SSL lifecycle (Phase 12):** local-first certificate health, renewal, and repair; no continuous phone-home; no automatic DNS-provider mutation; challenges carry operational binding metadata only.
- **Honest residual:** Full Root can replace the local helper / rewrite offline ledger — not unbreakable DRM.
- **`local_license_guard`:** unchanged.
- See `STAGE_OPERATION_AUTHORIZATION_MODEL.md`, `STAGE_COMMERCIAL_ENFORCEMENT_THREAT_MODEL.md`.

## Phase 11 — Multi-stage runtime (PASS)

- **`--stage` wired:** modular installer creates multiple isolated Stages per exact License.
- **Local clone only:** `pg_dump` + filestore copy stay on the customer server — never uploaded to SaaS.
- **Dedicated networks:** `soviez-net-stage-<id>` per Stage; no Core Slot consumption.
- **Expiry sovereignty preserved:** expired Stage License denies new create only; existing Stages remain startable/stoppable/backupable/droppable.
- **Helper-required certification:** not Bash-only; Full Root residual disclosed — not DRM.
- **No retention auto-delete** in this phase; no periodic phone-home.
- See `MULTI_STAGE_RUNTIME_MODEL.md`, `docs/user/STAGE_ENVIRONMENTS.md`.

## Phase 13 — Stage retention (PASS)

- **Local-only:** retention metadata, calendar countdown, warning ledger, final backup, Safe Shield, deletion, retry, and tombstone operate on the customer-controlled host.
- **No phone-home:** the scheduler does not check entitlement or call SaaS, and it never uploads a backup, database, filestore, log, or secret.
- **Not a commercial kill-switch:** Stage License/ticket expiry does not trigger retention or stop/delete an existing Stage.
- **Fail closed:** backup or ownership uncertainty leaves the Stage in Needs Action/recovery-required state rather than deleting it.

## Phase 14 — Unified Operation Engine (PASS)

- **Local-first registry and status:** Local indexing, locks, history, status, and command adapters require no communication with Soviez SaaS and do not perform any background phone-home operations. All diagnostic checks, lock reconciliations, and state migrations occur completely in local sandbox boundaries.

## Phase 15 — Safe Update (PASS)

- **No business data to SaaS:** update entitlement/registry calls send only disclosed operational metadata; recovery sets and candidates stay local.
- Support expiry never stops installed ERP.

## Phase 16 — Production Backup / Restore (PASS)

- **Backup never to SaaS:** Production backups are written locally and optionally to **owner-controlled** S3-compatible or SFTP destinations only.
- **No Soviez-hosted backup product**; SaaS must never receive dumps, filestore archives, backup packages, encryption passphrases, or destination secrets.
- Restore is **same-host** and candidate-first; cross-host restore is denied (migration is a later phase).
- Local schedule/retention/verify/restore-test require **no** SaaS contact.
- See `PRODUCTION_BACKUP_AND_RESTORE_MODEL.md`, `docs/dev/BACKUP_SECURITY_THREAT_MODEL.md`.

## Phase 17 — Migration Discovery / Trust Pairing / Destination Bootstrap (PASS)

- **No business payload transfer** in Phase 17; discovery collects aggregates and identities only.
- Final certification closure: `docs/evidence/phase-17-final-certification-closure/` — progress **89%**.
- **No SaaS relay** of DB/filestore/addons; Migration Token may be eligibility-checked only (never reserve/consume).
- Destination bootstrap is temporary / non-sellable / non-slot; Production activation deferred to later phases.
- Trust uses Device Authorization + application-signed objects + mTLS; no shared permanent password; no `SOVIEZ_MIGRATION_SECRET` as primary trust.
- See `MIGRATION_DISCOVERY_AND_BOOTSTRAP_MODEL.md`.

## Phase 18 — Domain / DNS / Landing / TLS / Routing Readiness (PASS)

- **Local-first control plane** for migration subdomain preparation; no business payload egress.
- DNS ownership, landing, and mig-FQDN TLS stay on customer hosts; SaaS must never hold DNS provider credentials or TLS private keys.
- Abort preserves owner DNS; source Production traffic unchanged; token not reserved/consumed.
- Progress **93%** (89+4). Installer `0.18.0-phase18`. See `MIGRATION_DOMAIN_AND_ROUTING_READINESS_MODEL.md`.

## Phase 22 — Source Archive / Retirement Readiness (PASS)

- **Archive ≠ purge:** reversible encrypted local/owner-controlled archive only; no source/backup delete, cert revoke, or host terminate.
- **No SaaS archive payload:** dumps, filestore packages, encryption passphrases, and restore-test datasets never leave customer control toward Soviez.
- Progress **98%** (97+1). Installer `0.22.0-phase22`. Phase 23 Offline bundles remain UNAUTHORIZED; purge is not Phase 23.
- See `MIGRATION_SOURCE_ARCHIVE_AND_RETIREMENT_MODEL.md`, `docs/evidence/phase-22-source-archive-retirement/`.

## Security Gate S1 — Critical Containment (PASS)

- **Containment boundary:** compromised Odoo must not equal compromised PostgreSQL host / server.
- Bootstrap PG admin credentials are never passed into the Odoo runtime env; app role is least-privilege.
- No new SaaS egress; security validation is local fail-closed.
- Progress remains **99.5%**. Phase 25 paused pending S2–S6. See `docs/evidence/security-gate-s1/`, `docs/security/CRITICAL_CONTAINMENT_GATE.md`.


### Security Gate S2
Host/edge hardening is part of the sovereign on-host security platform. No hidden Cloudflare phone-home; CF IP refresh is operator-initiated. Progress credit unchanged at 99.5%.

### Security Gate S3
Compromise detection evidence and findings remain **local-only**. No automatic upload of security findings, DB snippets, or host inventories to SaaS. No hidden telemetry. Progress remains 99.5%. Phase 25 paused pending S4–S6.

### Security Gate S4
Quarantine metadata and findings remain local-only. No security telemetry. Progress remains 99.5%.

### Security Gate S5
Update and backup safety evidence remains local-only. Off-host backups are customer-controlled S3-compatible or SFTP only — never Soviez SaaS. LOCAL_ONLY ≠ DR-capable. No new business-data egress. Progress remains 99.5%. Phase 25 paused pending S6.

### Security Gate S6
Certification evidence remains local-only. No hidden security telemetry. Progress remains 99.5%. Security Platform CERTIFIED. Phase 25 READY FOR OWNER AUTHORIZATION; Release NOT AUTHORIZED.
