# Data egress contract

## Allowed (disclosed per op)

### Device authorization start (`device-egress/v1`) — implemented
Public key; fingerprint; optional sanitized label; protocol version; nonce.  
Plus inherent HTTPS metadata (e.g. source IP) — not app telemetry.

### Private registry pull (`registry-pull/v1`) — implemented (Phase 7 foundation)
Device PoP headers; operation_id; operation_type; release_id or release_version; architecture; idempotency_key; capability decision snapshot (server-side).  
Returns: digest, signed release manifest, short-lived pull ticket, gateway URL — **never** Docker Hub org token or business data.

### New instance connected activation (`new-instance/v1`) — implemented (Phase 8 foundation — PARTIAL)
Composes Phase 5 device auth, Phase 6 slot reservation, Phase 7 registry pull, plus local provisioning metadata.  
Transmits: operation_id, idempotency_key, fingerprint (after bind), activation_method, device PoP headers, release/digest correlation.  
Returns: slot_id, activation_key (stored locally at 0600 — **never re-logged**), pull session credentials (temp).  
**Never transmitted:** activation key in logs/argv; business DB/filestore; device private keys.

### Stage operation authorization (`stage-operation/v1`) — Phase 10.5 (PASS) + Phase 11 wiring
Device PoP; license_id; operation_id/type; host pubkey fingerprint; production fingerprint; database UUID; stage_id; stage_domain; release digest; tooling digest; architecture; entitlement decision ref; idempotency key.  
Returns: Stage Operation Ticket (`soviez.stage-operation.v1`) and/or offline package; status fields.  
Traceability fields only: `delivery_trace_id`, `subject_pseudonym` (license hash).  
**Never transmitted:** business DB/filestore; customer name/email as telemetry; Stage Operation private keys; continuous heartbeat.  
Ticket expiry gates START only — does not phone home to stop Stages.

### Stage runtime create (`stage-runtime/v1`) — Phase 11 (PASS)
User-initiated `--stage` may call entitlement check + operation authorize/consume/complete (connected) or export/import offline request/package.  
**Local only (never egress):** Production/Stage database dumps, filestore blobs, Stage secrets, nginx private keys, ACME account private keys, certificate private keys.  

### Domain/SSL lifecycle (Phase 12) — local-first
Certificate monitoring, renewal scheduling, Nginx ownership checks, and repair run locally. Optional future SaaS challenge verification (if used) must carry only pseudonymous operational binding metadata — never ERP data, dumps, filestore, or private keys. No continuous phone-home for certificate health.
Offline request type `soviez.stage-offline-request.v1` carries licensing/host/fingerprint/digest/stage identity metadata only.  
Remote completion (when online) sends neutralization/origin metadata — not business datasets.

### Stage retention (Phase 13) — local-only
Retention scheduling, countdown/banner rendering, warnings, final backup, Safe Shield validation, deletion, retry/reattach, and tombstone creation make **no network request**.  
**Never transmitted:** Stage/Production databases, filestore, backup archive or checksum, retention record, deletion steps, secret/config files, or unrestricted logs. Retention does not consult Stage License or ticket entitlement.

### Unified Operation Engine (Phase 14) — local-only
Local registration, index queries, lock acquisitions/releases, history append/list, CLI operation queries (`--operations`, `--operation-status|logs|cancel|retry|recover|reconcile`), and schema migration of Phase 8/11/12/13 states write and read strictly from local paths (e.g. `$SOVIEZ_OPS_ROOT/registry`) and make **no network requests** and perform **no phone-home**.
**Never transmitted:** Canonical JSON records, operation identifiers, process IDs, logs, event logs, local locks, or history lists. All diagnostic and operational control remains fully hostbound.

### Safe Update (Phase 15) — connected (minimum) + local-only offline
**Connected may send only (on explicit `--update`):** device identity proof, account id, exact License ID, exact Production environment id, current/target release digests, capability `product_updates`, idempotency key/nonce, request timestamp.
Endpoints: `/api/installer/entitlements/product-updates/check`, registry release resolve, short-lived pull-session create/refresh.
**Local only:** DB dumps, filestore, recovery sets, candidate workspaces, upgrade logs (redacted), rollback manifests, pull tokens (ephemeral; never durable).
**Offline `--offline-package`:** zero network after import. No periodic entitlement polling. Support expiry never stops installed ERP.

### Production Backup / Restore (Phase 16) — local / owner remotes only
Backup, verify, retention, schedule, restore-test, Production restore, rollback, export/import make **no SaaS requests** and upload **no** backup payloads to Soviez.
Optional transfer targets are **customer S3-compatible or SFTP** endpoints only (never Soviez SaaS).
**Forbidden to SaaS (absolute):** `pg_dump` outputs; filestore archives; Full backup packages; encrypted ciphertext destined for Soviez; encryption passphrases; destination access keys / SFTP identities; manifest HMAC keys; restore candidate datasets.
Stage live backup (`soviez_backup_stage_live_backup`) likewise stays on the customer host.

### Migration Discovery / Bootstrap / Pairing / Readiness (Phase 17) — metadata only
Phase 17 may transmit only the allowlisted non-sensitive metadata documented in the Phase 17 scope (account/License/environment IDs, public fingerprints, versions, digests, aggregate sizes, Stage IDs/statuses, eligibility, signed nonces, operation status, timestamps, idempotency keys).
**Forbidden to SaaS (absolute):** database dumps/contents; filestore; business filenames; addon source; config/env secret values; customer/employee/accounting records; passwords; private keys; unrestricted logs; backup payloads.
Migration Token: eligibility display only — **no** reserve/consume/burn in Phase 17.

### Migration Domain / DNS / Landing / TLS / Routing Readiness (Phase 18) — local-first metadata
Phase 18 is **local-first**. If a future optional connected assist is enabled, only allowlisted non-sensitive metadata may leave the host: `account_id`, `license_id`, `migration_pair_id`, `source_environment_id`, `destination_bootstrap_id`, migration FQDN, challenge token **hash** (prefer fully local verify), certificate/routing/operation status, timestamps, idempotency keys, public fingerprints, challenge expiry, validation result.
**Forbidden to SaaS (absolute):** database/filestore payloads; TLS private keys; ACME account private keys; DNS provider credentials; unrestricted logs; source web traffic; business records; Migration Token reserve/consume.
Default: no periodic phone-home; no SaaS proxy of customer traffic.

### Later connected ops (Planned — still disclosed per op)
Migration HMAC receipts (Phase 20). Streaming transfer is Phase 19 (certified separately). Phase 21 cutover metadata only. Phase 22 source archive packages, restore-test datasets, encryption passphrases, and backup pins are **local / owner-controlled only** — never SaaS payloads. Phase 23 Offline bundles remain UNAUTHORIZED.

### Source Archive / Retirement (Phase 22) — no archive payload egress
Stabilization, rollback-window closure receipts, archive operation status, and Phase 23 readiness reports may record local IDs/timestamps only.
**Forbidden to SaaS (absolute):** source archive packages; `pg_dump` / filestore archive bodies; archive encryption passphrases; secret inventory values; certificate private keys; DNS provider credentials; pinned backup blobs; unrestricted logs.
Archive vs purge: Phase 22 archives only; purge is separately authorized and is **not** Phase 23.
## Forbidden (Confirmed)
Business DB dumps; filestore; **Production/Stage backup archives and packages**; **Phase 22 source archive packages**; passwords; unrestricted logs; accounting/CRM/HR datasets; attachments; device private keys; activation keys; Stage Operation private signing keys in client artifacts; name/email/business data in tickets or tooling for telemetry; backup encryption keys; backup destination credentials; archive encryption passphrases.

### Security Gate S1 — local containment only
Critical containment validation (`--security-check` / Production gate) runs **entirely on the customer host**. It must never upload databases, role passwords, security reports with secrets, or filestore to Soviez SaaS. Security evidence stays local (redacted).

## Existing
Installer↔SaaS business egress: none observed in legacy script for dumps.  
Device auth does not transmit business data.

## Planned enforcement
Static allowlists in entitlement client; CI greps for scrape/upload patterns.


### Security Gate S2
Host/edge hardening is part of the sovereign on-host security platform. No hidden Cloudflare phone-home; CF IP refresh is operator-initiated. Progress credit unchanged at 99.5%.

### Security Gate S3
`--security-scan-db` / compromise detection runs entirely on-host. Findings, baselines, and evidence manifests must not egress to SaaS. Redacted local evidence only. No phone-home IOC refresh.

### Security Gate S4
Quarantine networks deny external egress by default. Quarantine evidence does not egress to SaaS.

### Security Gate S5
No new SaaS egress. Backup payloads and destination credentials must not leave the customer trust boundary except to customer-controlled S3-compatible/SFTP endpoints. S5 evidence stays local. LOCAL_ONLY backups are not DR egress.

### Security Gate S6
S6 certification audits confirm no hidden security telemetry phone-home. Findings/evidence stay local. No new business-data egress beyond disclosed contracts. Progress remains 99.5%.
