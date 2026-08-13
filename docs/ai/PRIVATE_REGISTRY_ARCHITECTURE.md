# Private registry architecture

> **Canonical model:** [`PRIVATE_REGISTRY_AND_PULL_AUTHORIZATION_MODEL.md`](./PRIVATE_REGISTRY_AND_PULL_AUTHORIZATION_MODEL.md)  
> **Implementer protocol:** [`../dev/PRIVATE_REGISTRY_PROTOCOL.md`](../dev/PRIVATE_REGISTRY_PROTOCOL.md)  
> **Client Gateway contract:** [`../dev/REGISTRY_GATEWAY.md`](../dev/REGISTRY_GATEWAY.md) (server ops are internal)

---

## ADR summary — Phase 7 (PASS)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Blob transport** | Dedicated Node gateway (internal `soviez-registry-gateway/`; **not** published in `soviez-deploy`) | Multi-GB OCI streaming, Range support, no Vercel body/timeout limits |
| **SaaS role** | Entitlement + ticket issuance only | Next.js never proxies blobs |
| **Upstream storage** | Docker Hub (pull-only creds in gateway env) | Existing image pipeline; clients never see Hub tokens |
| **Client credential** | Ed25519 pull ticket, domain `soviez.registry-pull-ticket.v1` | Offline gateway verification; pull-only scope |
| **Release authority** | Digest-first catalog + signed manifest `soviez.release-manifest.v1` | No `:latest`; tamper-evident metadata |
| **Authorization stack** | Device PoP + `private_image_pull` capability | No blanket account access; test grants only in certification |
| **Session model** | Short-lived pull sessions in Postgres (`083`) | Idempotent create; refresh/revoke/complete lifecycle |
| **Gateway cache** | In-memory session digest graph only | No cross-session blob cache; restart-safe via re-fetch |
| **ERP runtime** | Independent of registry/SaaS | Pull is optional connected operation |
| **Installer wiring** | Deferred | Foundation APIs + docs only; no `local_license_guard` changes |

**Rejected:** Proxying OCI through Vercel/Next.js API routes.

**Deferred:** Live Hub private cutover, installer orchestration, full offline distribution (Phase 23).

---

## Evidence

Phase 7 gate: `docs/evidence/phase-07-private-registry/FINAL_REPORT.md`
