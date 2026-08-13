# DATA_EGRESS_MODEL.md

## Principle

Phase 21 cutover emits **metadata and audit events only** — no business payloads to SaaS.

## Permitted egress (metadata)

| Data | Destination | Purpose |
|------|-------------|---------|
| `authorization_id`, `license_id` | SaaS ledger | Cutover audit |
| `traffic_owner` transitions | SaaS ledger | Authoritative epoch |
| `traffic_cutover_started`, timestamps | SaaS ledger | Compliance |
| Health check **results** (PASS/FAIL codes) | SaaS ledger | Support visibility |
| Rollback events | SaaS ledger | Audit |
| DNS instruction **hashes** (not zone credentials) | Local report | Integrity |
| Operator attestation (boolean + time) | Local + optional SaaS metadata | Procedure |

## Forbidden egress

| Data | Reason |
|------|--------|
| DB rows / filestore blobs | Phase 19 already local |
| ERP business documents | Sovereignty |
| DNS provider API keys | Secrets stay local |
| Customer PII in health smoke logs | Minimize; redact |
| Full HTTP response bodies in SaaS | Metadata only |
| SaaS traffic relay payloads | Architecture forbidden |

## Local-only artifacts

- Full DNS instruction document with targets (IPs are infrastructure metadata — local report).
- Health probe detailed logs.
- nginx/SSL configs.
- Rollback runbooks.

## SaaS UI

Frozen — no cutover wizard in Phase 21 scope. Future UI is separate authorization (Phase 20 OD-48 analog).

## Offline path

Manual DNS and offline attestation files remain on installer host; reconcile metadata when connected — no business data upload.

## Compliance

Align audit retention with License lifetime (Phase 20 OD-46 analog) — owner confirm OD-36.

## OWNER DECISION REQUIRED

**OD-36:** Upload health failure **codes** only vs aggregated status to SaaS?

**Recommendation:** **Codes only** — no stack traces.
