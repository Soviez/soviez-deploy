# Privacy and sovereignty

## Confirmed product promise

Your running Soviez ERP does not require continuous contact with Soviez Cloud.
Soviez Cloud never receives your business database or filestore as part of install, update, Stage, or migration.

## Existing today

- Licenses are verified offline inside your server.
- Installer operations that talk to the internet today are limited (DNS, Certbot, digest-pinned image pull via short-lived Registry credentials, and signed update/offline bundle fetch when you initiate them) — not business data upload. Unsigned script self-update is not supported; production updates require cryptographic signatures.
- **Device authorization (optional):** a browser-assisted link between a server public key and your customer account. Used only when you start that flow. Transmits only minimal device metadata (public key, fingerprint, optional label, protocol version, nonce). No phone-home loop.
- **Private registry pull (Phase 7 + 8):** when you request an image pull during `--new` or update, Soviez checks entitlement and issues a **temporary, pull-only** credential bound to one digest. No Docker Hub org token is stored on your server. No push access. Running ERP is unaffected if SaaS or registry is down.
- **New instance connected install (Phase 8):** `soviez.sh --new` orchestrates device auth, slot reservation, image pull, and optional automatic activation. Each step is disclosed before send. Activation keys are never logged or passed as command arguments.
- **Annual Technical Support (Phase 9):** support coverage and expiration are tracked in Soviez Cloud for billing and portal display only. Your running ERP **does not phone home** to check support status. Expiration does not deactivate ERP, block login, remove data, or block backup/restore. Product update entitlement is evaluated only when **you** initiate an update (installer `--update` wiring is a later phase).

## Authorizing a server — plain language

| Claim | True? |
|-------|-------|
| Sends accounting / CRM / HR data | **No** |
| Consumes a License Slot by itself | **No** |
| Activates ERP by itself | **No** |
| Lets Soviez shut down your ERP | **No** |
| Can be revoked later | **Yes** |
| Gives permanent Docker Hub password | **No** — short-lived pull ticket only |
| Requires `:latest` tag trust | **No** — digest-pinned only |

## Private pull — sovereignty table

| Data | Sent to Soviez? | Sent to registry gateway? |
|------|-----------------|---------------------------|
| Business DB / filestore | **Never** | **Never** |
| Device public key + PoP | Yes (API auth) | No |
| Image digest + operation id | Yes | Embedded in pull ticket |
| Docker Hub org token | **Never** | **Never on client** (gateway-only secret) |
| Layer blob bytes | No | Streamed client ↔ gateway ↔ Hub |

## Annual Support — sovereignty table (Phase 9)

| Data / behavior | Sent to Soviez? | Affects ERP runtime? |
|-----------------|-----------------|----------------------|
| Support coverage status (portal) | Stored in Cloud; you view in portal | **No** |
| Automatic ERP shutdown on expiry | **Never** | **No** |
| Continuous support heartbeat | **Never** | **No** |
| Product update entitlement check | Only when **you** start an update (future `--update`) | Gates update pull only |
| Business DB / filestore | **Never** | N/A |

## Stage License — sovereignty table (Phase 10)

| Data / behavior | Sent to Soviez? | Affects ERP runtime? |
|-----------------|-----------------|----------------------|
| Stage entitlement status (portal) | Stored in Cloud; you view in portal | **No** |
| Automatic Stage shutdown on expiry | **Never** | **No** |
| Continuous Stage heartbeat | **Never** | **No** |
| Stage create/clone gate | Only when **you** run gated ops (`--stage`) | Gates new Stage ops only |
| Existing Stages on expiry | **Never deleted by billing** | **No** |

## Stage operation authorization — disclosure (Phase 10.5)

Stage creation requires **operation authorization**. When you start a gated Stage operation, Soviez receives only **minimal licensing metadata** (license/device/host identifiers and fingerprints, digests, stage identity). **No business data** is sent.

| Claim | True? |
|-------|-------|
| Stage continues offline after creation | **Yes** |
| Expired Stage License stops/deletes Stages | **No** |
| Private tooling may include a pseudonymous delivery ID | **Yes** (leak attribution only — not a phone-home beacon) |
| Full Root can bypass local software checks | **Yes** (honest residual) |
| Unbreakable DRM | **No** — Soviez does not claim this |

| Data / behavior | Sent to Soviez? | Affects running Stage? |
|-----------------|-----------------|------------------------|
| Operation ticket request (user-initiated) | Minimal licensing metadata only | Gates **START** only |
| Business DB / filestore / name / email | **Never** | N/A |
| Stage-origin certificate | **Local only** (no phone-home) | Evidence; survives entitlement expiry |
| Ticket expiry after Stage is running | N/A | **Does not stop** the Stage |

## Stage runtime — disclosure (Phase 11)

Creating a Stage with `soviez.sh --stage` clones your Production **on your server** (`pg_dump` + filestore copy). Those copies are **never uploaded** to Soviez Cloud. Connected steps only exchange licensing/authorization metadata (or an offline package you transport yourself).

| Claim | True? |
|-------|-------|
| Multiple Stages per License | **Yes** (server resources permitting) |
| Core License Slot consumed by Stage | **No** |
| Shared writable filestore with Production | **No** |
| Self-signed accepted as complete Stage SSL | **No** |
| Automatic 60-day retention deletion | **Not yet** |

## Planned

Further connected entitlement calls (migration tokens, installer `--update`) will use the same disclosure discipline and separate commercial checks — device auth alone is never enough.

## Automatic activation — sovereignty table

| Data | Sent to Soviez? | Stored on server? | In logs? |
|------|-----------------|-------------------|----------|
| Activation key | Issued via API; ack only after local ORM | Yes, mode 600 | **Never** |
| Fingerprint | Yes (bind step) | Yes | Redacted in debug |
| Business DB / filestore | **Never** | Local only | **Never** |
| Device private key | **Never** | Local only | **Never** |
