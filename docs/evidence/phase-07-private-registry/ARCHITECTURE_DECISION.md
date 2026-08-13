# Architecture decision — Phase 7 Private Registry

**Status:** Binding — **ACCEPTED**  
**Date:** 2026-07-30

## Context

Soviez ERP images are stored on Docker Hub. Customers need authorized, digest-pinned pulls without receiving long-lived Hub credentials. Multi-gigabyte OCI layer downloads require streaming proxy support.

## Decision

Implement a **two-tier architecture**:

1. **Soviez SaaS (Next.js on Vercel)** — commercial entitlement, release catalog, pull-session lifecycle, Ed25519 ticket issuance. **Does not stream blobs.**

2. **Registry Gateway (Node HTTP service)** — verifies pull tickets offline, proxies authorized OCI v2 requests to Docker Hub with server-side pull-only credentials, maintains in-memory digest graph per session.

## Key bindings

| Topic | Decision |
|-------|----------|
| Ticket domain | `soviez.registry-pull-ticket.v1` |
| Manifest domain | `soviez.release-manifest.v1` |
| Migration | `083_private_registry_pull_foundation.sql` |
| Capability | `private_image_pull` via `commercial_grants` (seed mapping only; no blanket access) |
| Upstream | Docker Hub (`registry-1.docker.io`) |
| Client creds | Short-lived pull ticket + opaque client token; temp `docker --config` |
| Cache | In-memory session digest graph only (no persistent blob cache) |
| ERP runtime | Never depends on registry/SaaS availability |

## Rejected alternatives

| Alternative | Reason rejected |
|-------------|-----------------|
| Vercel/Next.js blob proxy | Body limits, timeouts, bandwidth cost, poor Range streaming |
| Client-side Hub org token | Credential exfiltration risk; no per-pull scoping |
| `:latest` tag authority | Non-reproducible installs; tamper surface |
| Gateway business logic / Supabase | Separation of concerns; gateway stays stateless aside from session graph |

## Consequences

- Additional deployable service (`services/registry-gateway`) with its own env secrets
- Hub pull credentials rotated in gateway only
- Installer must orchestrate temp docker config (deferred wiring)
- CI prep workflow emits candidate metadata; human/process approval before `published`

## References

- `docs/ai/PRIVATE_REGISTRY_AND_PULL_AUTHORIZATION_MODEL.md`
- `docs/evidence/phase-07-private-registry/VERCEL_SUITABILITY_REVIEW.md`
