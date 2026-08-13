# Registry gateway

Dedicated Node streaming OCI gateway for Phase 7 private registry pulls.

**Canonical model:** `docs/ai/PRIVATE_REGISTRY_AND_PULL_AUTHORIZATION_MODEL.md`  
**Protocol:** `docs/dev/PRIVATE_REGISTRY_PROTOCOL.md`  
**Source:** `services/registry-gateway/`

## Purpose

- Speaks Docker Registry HTTP API V2 for pull clients
- Verifies short-lived Soviez pull tickets (Ed25519, `soviez.registry-pull-ticket.v1`) **offline**
- Proxies only the authorized repository + digest graph to Docker Hub upstream
- Never exposes upstream credentials to clients
- Streams blobs without whole-layer buffering; supports Range requests
- Denies push, delete, catalog, and tag listing

## Deployment

See `services/registry-gateway/README.md` for environment variables, endpoints, and operations (`npm test`, `npm start`).

## Security

- Hub pull-only token in gateway env only (`SOVIEZ_UPSTREAM_REGISTRY_USER`, `SOVIEZ_UPSTREAM_REGISTRY_TOKEN`)
- Ticket public keys in `SOVIEZ_REGISTRY_TICKET_PUBLIC_KEYS_JSON`
- No Supabase or SaaS business logic in this service
- In-memory session digest graph only — not a shared blob cache
