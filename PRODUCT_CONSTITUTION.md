# Soviez Product Constitution

**Binding contract** for the Soviez deployment engine (`soviez-sh`), commercial entitlements, staging, updates, private image distribution, and sovereign migration.

**Status:** Confirmed decision for planning. Implementation not authorized until the owner opens a subsequent phase.

**Last updated:** 2026-08-12 (Phase 25 PASS; Engineering 100%; Security Platform CERTIFIED; Official Documentation CANONICAL / CODE-SYNCHRONIZED; installer `0.24.5.1-security-s5-corr1`; Release NOT AUTHORIZED)  
**Authority:** Project owner. Future AI/developers must obey this document over convenience.

---

## 1. Product purpose

Deliver a modular, sovereign deployment and operations engine that:

- Installs and operates self-hosted Soviez ERP on customer-controlled servers.
- Enforces commercial entitlements for optional capabilities only.
- Preserves offline-first runtime independence.
- Produces one distributable `soviez.sh` while maintainable source lives under `/soviez-sh`.

Legacy reference installer: `soviez-deploy/soviez.sh` (read-only during discovery). Canonical future source: `/Volumes/PortableSSD/soviez-project/soviez-sh`.

---

## 2. Sovereignty First

1. The customer’s running ERP must never depend on continuous access to Soviez SaaS.
2. No hidden telemetry.
3. No periodic phone-home unless the owner separately approves an explicit future feature.
4. Every online communication must be caused by an operation initiated or approved by the user.
5. Before communication, the installer must disclose exactly what metadata will be transmitted.
6. Business records, accounting data, customer data, employee data, attachments, database dumps, filestore contents, passwords, and unrestricted logs must never be transmitted to Soviez SaaS.
7. Database and filestore migration must occur directly between customer-controlled servers or through customer-controlled offline media.
8. SaaS must never proxy or receive business databases or filestore data.
9. Local operations registry, local operation state status queries, conflict detection, locks, and recovery/reconciliation must run 100% locally and require no SaaS access, nor generate any outbound phone-home.

---

## 3. Privacy and data minimization

Allowed online metadata (examples, still disclosed per operation):

- Account identity tokens for device authorization.
- License identifiers, fingerprints (`HARDWARE_HASH::database.uuid`), image digests, operation nonces.
- Entitlement check inputs (tenant name, public key fingerprint, release target).
- Migration receipts / HMAC material already defined by the license migration protocol.

Forbidden egress: any business dataset, dump, filestore blob, unrestricted log stream, **Production/Stage backup archive**, backup encryption passphrase, or backup destination credential material to Soviez SaaS.

### Production backup & restore sovereignty (Phase 16)

1. Production Full backup and same-host restore are **local / owner-destination** operations — never Soviez-hosted.
2. SaaS must never receive backup payloads, manifests’ secret fields, encryption keys, or S3/SFTP credentials.
3. Optional remotes (S3-compatible, SFTP) are customer-controlled only; encryption is mandatory for remotes and default-on for local.
4. Restore is candidate-first and same-host; cross-host restore is not a Phase 16 product (migration is separate).
5. Absence of SaaS connectivity must never block local backup, verify, restore-test, or restore/rollback.

See also: `docs/ai/DATA_EGRESS_CONTRACT.md`, `docs/ai/PRODUCTION_BACKUP_AND_RESTORE_MODEL.md`, `docs/user/PRIVACY_AND_SOVEREIGNTY.md`.

---

## 4. Runtime independence

Expiration or absence of a commercial add-on must never:

- Stop Production.
- Block login.
- Block business data.
- Block backup, restore, diagnostics, or local recovery.
- Delete Production.
- Delete or stop an existing Stage merely because Stage entitlement expired.

Commercial entitlements control **access to new optional capabilities** only.

---

## 5. Connected-mode rules

Connected mode may provide:

- Browser/device authorization.
- Private image pull sessions.
- License Slot reservation.
- Automatic activation.
- Update entitlement.
- Stage entitlement.
- Migration-token processing.

All connected calls require explicit user-initiated operations and pre-flight disclosure.

---

## 6. Offline-mode rules

Offline mode is a first-class workflow for isolated environments and must support, where applicable:

- Signed installer package.
- Signed image archive.
- Fingerprint export.
- Manual activation.
- Offline entitlement package.
- Offline update bundle.
- Offline migration receipt/key exchange.
- Signature and digest verification.

---

## 7. Provider-neutral payment rules

1. Do not design eligibility around Stripe alone.
2. Stripe is one payment source among others.
3. The platform must support Stripe, future gateways, offline/manual payments, admin-issued grants, complimentary grants, and provider refunds/disputes/chargebacks/manual revocation.
4. Entitlement source of truth is a provider-neutral commercial ledger/grant model inside Soviez SaaS.
5. Admin/manual grants are first-class — not fake Stripe payments (synthetic Stripe IDs are a current implementation smell to migrate away from).
6. Entitlement code must ask: “Does this account/license have a valid commercial grant for this capability?” — not “Was this paid through Stripe?”

---

## 8. License Slot rules

Creating a new Production system requires one successful, available License Slot owned by the authenticated account, that is valid, not refunded/reversed/revoked, not consumed, and not reserved by another active operation.

A qualifying Slot may originate from settled online payment, future gateway, approved offline payment, or explicit admin grant.

Reservation and consumption must be concurrency-safe and idempotent.

---

## 9. Annual support rules

1. New sales: Annual Technical Support only.
2. Capabilities: `technical_support = true`, `product_updates = true`.
3. Existing monthly subscriptions must not break during migration, but Monthly Support must **not** authorize product updates.
4. Annual support must link to the exact immutable `license_id`.
5. Prepaid multi-year terms supported; year-count discounts configurable in admin UI — never hard-coded.
6. Early renewal extends from `max(current valid_until, now)`.
7. Expiration blocks future product updates and covered support services only — never runtime.

---

## 10. Stage License rules

1. Monthly Stage License add-on linked to one exact `license_id`.
2. Active entitlement allows multiple Stage environments for that license, subject to server-resource checks.
3. Must not apply account-wide or authorize Stages for another license.
4. Expiration prevents new Stage creation, cloning, or refresh.
5. Expiration does **not** stop, delete, or block access to existing Stages.
6. Listing, backup, stop, and safe deletion remain available after expiry.

---

## 10.5. Stage Operation Authorization rules (Phase 10.5)

**Confirmed decision — commercial hardening, not DRM.**

1. Gated Stage operations require a signed **Stage Operation Ticket** after Stage License entitlement and Device Auth succeed.
2. Signing domain is **`soviez.stage-operation.v1`** — separate from Device Auth, License, release-manifest, registry pull tickets, Migration HMAC, and Stripe.
3. Tickets bind license, device, host pubkey fingerprint, production fingerprint, database UUID, stage ID, domain, release digest, tooling digest, architecture, and operation.
4. Ticket expiry gates **START** of the operation only — never stops an existing Stage.
5. Offline packages plus a local consumption ledger are first-class; Full Root can tamper with local ledger/helper — residual risk, not denied.
6. Stage-origin certificates are **local evidence only** (no phone-home) and survive entitlement expiry.
7. Traceability is limited to `delivery_trace_id` + `subject_pseudonym` (license hash) — no name, email, or business data.
8. Private Stage tooling is digest-pinned via private registry (`signed_package`); helper is Node TypeScript — not Bash-only.
9. Soviez does **not** claim unbreakable DRM. Full Root can replace the local verifier.
10. Phase 10.5 does **not** change `local_license_guard`. Phase 11 wires `--stage` and Stage containers while preserving helper-required certification.

See: `docs/ai/STAGE_OPERATION_AUTHORIZATION_MODEL.md`, `docs/ai/STAGE_COMMERCIAL_ENFORCEMENT_THREAT_MODEL.md`.

---

## 10.6. Multi-Stage Runtime rules (Phase 11)

**Confirmed decision — secure multi-stage runtime.**

1. One exact Production License may have **multiple** Stage environments.
2. Commercial Stage count is **unlimited** while Stage entitlement is active; local **resource admission** may block or warn.
3. Every Stage has unique ID, database, container, MAC, domain, SSL, filestore, config/secrets, Stage-origin certificate, and a **dedicated** Docker network `soviez-net-stage-<id>`.
4. A Stage binds one exact Production (license, fingerprint, database UUID) and does **not** consume a Core License Slot.
5. Snapshot uses **`pg_dump`** (never live PostgreSQL data directory). Filestore is **copied** — no shared writable storage with Production.
6. Gated create requires Device Auth + Stage License + Stage Operation Ticket + helper verification; neutralization is helper-certified.
7. Trusted CA HTTPS is mandatory for Stage acceptance; **self-signed is rejected** as final PASS.
8. Entitlement/ticket expiry blocks gated **START** only — never stops, deletes, or blocks list/status/start/stop/backup/safe drop of existing Stages.
9. Drop/cleanup touches only Stage-owned or explicitly selected resources — never Production, never global Docker prune.
10. Retention auto-delete remains Phase 13. Soviez does **not** claim unbreakable DRM; Full Root can replace the helper.

See: `docs/ai/MULTI_STAGE_RUNTIME_MODEL.md`, `docs/dev/STAGE_RUNTIME_PROTOCOL.md`, `docs/user/STAGE_ENVIRONMENTS.md`.

---

## 11. Stage mandatory domain/SSL

Every Production and every Stage environment must have a mandatory domain or subdomain and HTTPS.

The installer must validate DNS resolution, destination address, signed Soviez challenge endpoint, HTTPS availability, certificate validity, and correct environment signature.

A Stage is not successfully created until domain/SSL validation passes.

DNS waiting UX: finite user-controlled Try Again / Abort Safely — never silent infinite poll.

**Phase 12** owns post-provision certificate lifecycle (expiry monitoring, renewal, rotation, rollback, Nginx ownership, local repair) for Production and Stage. See `docs/ai/DOMAIN_SSL_LIFECYCLE_MODEL.md`. Initial Stage domain/SSL acceptance remains Phase 11.

---

## 12. Stage retention

Every new Stage has a default retention lifetime of **14 calendar days** from immutable original creation, disclosed before creation. The absolute maximum is **60 calendar days** from that same original creation; extensions never reset the clock and `--days` means total lifetime.

Record: immutable `created_at`, current and maximum deadlines, policy, warnings issued, extension state, final-backup evidence, Safe Shield result, and deletion/recovery state.

Local warnings and a daily neutralization-banner countdown precede deletion. Automatic deletion requires a verified final backup and Stage Safe Shield checks. Ambiguity or failure becomes Needs Action/recovery-required. Retention is local-only, causes no phone-home, and is caused by the disclosed retention policy — **not** commercial entitlement expiration.

---

## 13. Update boundaries

`--update` requires exactly one explicit Production tenant. Never update every system implicitly.

Eligibility: account owns license; annual support linked to same `license_id`; `product_updates = true`; valid period; valid provider-neutral grant state; not refunded/reversed/disputed/charged-back/manually revoked.

Monthly or unbound support must not qualify. Support expiration blocks only the new update.

---

## 14. Migration Token invariants

Preserve the existing migration-token commercial model.

Each authorized source→destination license migration consumes exactly one Migration Token linked to the same license.

Do not bypass: deactivation wizard, HMAC receipt, Shadow Lock, `database.uuid` rotation, anti-rollback, SaaS token burn, license rebind, destination activation key.

Retries must not burn a second token.

---

## 15. Migration assistant safety rules

Phase 17 delivers discovery / trust pairing / destination bootstrap. Phase 18 delivers migration-domain plan, signed DNS ownership, destination maintenance landing, mig-subdomain TLS, and routing readiness — **without** payload transfer, token consume, destination Production activation, or Production cutover.

Future streaming/`--migrate-in` (Phase 19+, separately authorized) must:

- Connect source↔destination directly (no SaaS data proxy).
- Bootstrap destination with signed installer + destination `--init`.
- Require mandatory destination domain and signed HTTPS maintenance landing.
- DNS/HTTPS/challenge validation with Try Again / Abort Safely only.
- Abort leaves source operating if irreversible cutover has not begun.
- After verification: source maintenance, stop writes, stream DB/filestore/addons/config.
- Avoid large temporary archives on source when streaming is possible.
- Allow Production only / Production+all Stages / Production+selected Stages.
- Complete existing license-migration receipt/token flow.
- Validate destination; replace landing page with ERP.
- Keep source stopped and retained by default; ask separately to retain/archive/purge.
- Never purge automatically; never global Docker prune; never delete unselected Stages.
- Resume after disconnect/reboot via persistent workers; reconcile state.

---

## 16. Source-retirement rules

Source retirement is an explicit operator decision after successful destination certification.

Never automatic purge. Never global Docker prune. Never delete Stages that were not selected for migration.

**Phase 22 (PASS):** After traffic cutover, close the rollback window only with eligibility + explicit owner confirmation; create a reversible verified source archive (not purge); finalize source License to `migrated_source_archived`; suspend source runtime while retaining host, backups, certificates, and DNS rollback snapshots. Archive packages and restore-test artifacts stay on customer-controlled storage — never relayed to Soviez SaaS. Purge/delete/cert-revoke/host-terminate remain forbidden here and are not Phase 23 (Offline bundles).

---

## 17. Private image distribution rules

Customers must never receive permanent Docker Hub credentials, organization access tokens, reusable registry credentials, or Supabase service-role keys.

Flow: entitlement → short-lived pull session → exact repository and digest → temporary Docker auth → secure cleanup.

Installer pulls by digest, not `:latest`. Offline installs use signed image archives.

---

## 18. Automatic activation rules

Automatic activation belongs to `--new`, not `--init`.

User must choose: (1) connect and activate automatically, or (2) activate manually later.

Automatic path sends only minimum licensing metadata after consent.

Manual path preserves fingerprint → SaaS key → paste.

Existing local Ed25519 offline runtime guard remains operational.

Do not bypass official ORM activation. Do not inject license parameters with unsafe direct SQL.

---

## 19. Documentation rules

- AI, user, and developer documentation must stay current with behavior.
- Undocumented behavioral changes are forbidden.
- Label Existing / Planned / Missing / Unsafe / Requires owner decision / Confirmed decision.
- Do not fabricate implemented behavior.

---

## 20. Testing rules

Any future change to `soviez-saas` or `local_license_guard` must include baseline, unit, integration, regression, failure, backward-compatibility, and security tests, plus documentation and evidence reports.

License-guard and SaaS minimum coverage lists are defined in `docs/ai/TEST_REQUIREMENTS.md` and `docs/dev/TEST_STRATEGY.md`.

---

## 21. No-technical-debt rule

Do not add technical debt inside the active scope. Temporary shortcuts require an explicit owner decision recorded in `docs/ai/DECISION_LOG.md` with a removal gate.

---

## 22. Authorization of release actions

Do not commit, push, merge, tag, deploy, publish images, apply production migrations, or alter live SaaS/ERP behavior without explicit owner authorization for that action.

---

## 23. Forbidden Behaviors

1. Hidden telemetry.
2. Continuous runtime phone-home.
3. Runtime shutdown due to support expiry.
4. Existing Stage shutdown or deletion due to Stage entitlement expiry.
5. Business-data egress to Soviez SaaS.
6. Stripe-only entitlement logic.
7. Account-level fallback for license-specific entitlements.
8. Implicit all-tenant update.
9. Optional domain for Production or Stage.
10. Stage without valid SSL (final acceptance).
11. Silent infinite DNS polling.
12. Permanent Docker registry credential in the installer.
13. Service-role key in the installer.
14. Direct SQL license injection.
15. Bypassing migration receipt/token flow.
16. Burning more than one migration token on retry.
17. Source purge before successful destination certification.
18. Global Docker prune as part of product workflows.
19. Editing generated `dist/soviez.sh` as the source of truth.
20. Undocumented behavioral changes.
21. Adding technical debt inside the active scope.
22. Treating `--init` as the automatic activation window.
23. Fake Stripe session IDs as the long-term grant model (migrate to provider-neutral grants).
24. Reusing `has_active_support_subscription*` for product updates or Stage entitlement.
25. Claiming unbreakable DRM for Stage commercial enforcement.
26. Using Stage Operation Ticket expiry (or Stage License expiry) as a kill-switch for existing Stages.
27. Embedding customer name, email, or business datasets in Stage tickets, tooling, or origin certificates.
28. Shipping Stage Operation private signing keys inside installer or tooling artifacts.
29. Reusing Device Auth / License / release-manifest / registry-pull / Migration HMAC / Stripe keys for Stage Operation Tickets.
30. Implementing user-visible capabilities without appropriate Customer and/or Admin UI coverage.
31. Deploying UI/UX/PX phases without a reachable preview URL and disposable demo credentials for owner inspection.

---

## 24. SaaS UX Requirements (Phase 11.5+)

A user-visible capability is incomplete until the appropriate Customer and/or Admin UI, UX states, permission boundaries, and browser tests exist.

UI/UX/PX phases require a reachable preview URL and disposable demo credentials for owner inspection before final acceptance.

---

## 25. Precedence

Product Constitution → Engineering/project docs under `/soviez-sh` → Mission prompt → Local decisions.

When uncertain, stop and ask the owner.


### Security Gate S2
Host/edge hardening is part of the sovereign on-host security platform. No hidden Cloudflare phone-home; CF IP refresh is operator-initiated. Progress credit unchanged at 99.5%.

### Security Gate S3
Compromise detection (DB/host/YARA/process/IOC) is local-only detect→report. No automatic remediation, no security telemetry phone-home, no SaaS upload of findings. Progress remains 99.5%. S4–S6 unauthorized; Phase 25 paused.

### Security Gate S4
Migration/restore quarantine is mandatory for untrusted databases. No automatic promotion. No destructive remediation. Progress remains 99.5%. S5–S6 unauthorized; Phase 25 paused.

### Security Gate S5
Update/backup/network safety: pre→post semantic validation; LOCAL_ONLY ≠ DR-capable; off-host = customer S3/SFTP only; APT wait-only (no killall). Progress remains 99.5%. S6 unauthorized; Phase 25 paused.

### Security Gate S6
Full security certification orchestrates S1–S5 + corr1 on the exact supported artifact. No claim of unhackable/malware-free. Progress remains 99.5%. Security Platform CERTIFIED. Phase 25 READY FOR OWNER AUTHORIZATION only; Release NOT AUTHORIZED.
