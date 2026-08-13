# Consent flow — Device Authorization

**Disclosure version:** `device-egress/v1`

## When consent is shown

Before a server completes device linking, the portal approval page (and future installer terminal disclosure) must show:

### Explicitly transmitted

- Public key
- Fingerprint
- Optional sanitized label
- Protocol version
- Nonce

### Visible as normal HTTPS metadata

- Source IP / TLS peer metadata (not app telemetry)

### Never transmitted

- Business ERP data, dumps, filestore, passwords, activation keys, private key, inventory/hostname (unless separately disclosed later)

## What approval means

Links this server key to the logged-in account for future authenticated connected operations that the customer explicitly requests.

## What approval does not mean

No Slot consumption, no purchase, no business-data access, no ERP shutdown right, no updates/Stages/Migration Tokens by itself.

## Actions

Approve · Deny — never preselected.
