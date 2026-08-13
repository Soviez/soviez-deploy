# DATA_EGRESS_MODEL.md

## Forbidden to SaaS

DB dumps/contents, filestore, attachments, addon source, config payloads, customer/employee/accounting records, passwords, License private secrets, device/TLS private keys, unrestricted logs, traffic, Stage payloads.

## Permitted metadata (necessary only)

account/License/environment IDs; migration-pair; Phase 19 transfer/readiness/staging IDs; token entitlement ID; ledger tx ID; fingerprints (public); DB UUIDs; image digests; environment states; selected Stage IDs; activation/grace states; idempotency key; operation ID; timestamps; signed public fingerprints; non-sensitive failure codes; compensation state.

No hidden telemetry; no periodic phone-home; no payload relay; no SaaS remote shell.
