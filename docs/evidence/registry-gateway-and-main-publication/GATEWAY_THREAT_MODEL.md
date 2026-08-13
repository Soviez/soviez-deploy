# GATEWAY_THREAT_MODEL — Soviez Registry Gateway

## Assets

| Asset | Location | Sensitivity |
|-------|----------|-------------|
| Docker Hub pull PAT | Gateway host env only | **Critical** |
| Ticket signing private key | SaaS secret store | **Critical** |
| Ticket public keys | Gateway env (`SOVIEZ_REGISTRY_TICKET_PUBLIC_KEYS_JSON`) | Public |
| Pull tickets | Client memory / docker config (short TTL) | High (time-bound) |
| OCI image layers | Upstream Hub | Commercial IP |
| Session/account/device bindings | Ticket claims + optional headers | Authorization boundary |

## Trust boundaries

```
[Untrusted: installer host / docker client]
        │ pull ticket only
        ▼
[Semi-trusted: gateway host]
        │ Hub credentials never returned
        ▼
[Trusted: SaaS issuer + key management]
        │ signs tickets offline-verifiable by gateway
        ▼
[External: Docker Hub]
```

## Threats and mitigations

| Threat | Mitigation | Test evidence |
|--------|------------|---------------|
| Upstream credential theft by client | Server-side proxy only; no credential in API responses | `NO_UPSTREAM_CREDENTIAL_EGRESS.md`, unit test "REG basic auth token exchange" |
| Ticket replay after expiry | `exp` enforced; code `PULL_SESSION_EXPIRED` | `TOKEN_EXPIRY_TEST.md` |
| Cross-repo pull | Repository allowlist; `REPOSITORY_SCOPE_DENIED` | `SCOPE_ENFORCEMENT.md` |
| Unauthorized blob (digest swap) | Digest graph after manifest fetch; `BLOB_SCOPE_DENIED` | Unit tests wrong digest / unauthorized blob |
| Push / catalog enumeration | Explicit denial (403/405) | Unit tests push, catalog, tags list |
| Credential leakage in logs | `src/redact.ts` + `safeLog` | `LOG_REDACTION.md` |
| Push scope via token endpoint | `METHOD_NOT_ALLOWED` on push scope | Unit test "REG push scope denied" |
| Wrong registry service/audience | `AUDIENCE_DENIED` | Unit test "REG wrong audience/service denied" |
| License/device binding bypass | Header + Basic username binding checks | Unit tests LICENSE_BINDING_DENIED, DEVICE_BINDING_DENIED |
| Rate-limit abuse | Per-IP rate limit (configurable) | Unit test rate limit 429 |
| Container escape / privilege | Non-root container, no docker.sock, caps dropped | `docs/SECURITY.md` |
| Secrets in git | `.gitignore`, example placeholders only | `SECRET_EXCLUSION.md`, `GITIGNORE_CLOSURE.md` |

## Out of scope (accepted risks)

| Risk | Rationale |
|------|-----------|
| Compromised gateway host | Host compromise exposes Hub PAT — operator hardening + rotation procedure in `docs/SECURITY.md` |
| Compromised SaaS signing key | Short ticket TTL (900s) limits blast radius; key rotation via public key map update |
| Denial of service at edge | nginx + rate limit; full DDoS handled at infrastructure layer |

## Residual items

| Item | Status |
|------|--------|
| Production TLS cert provisioning | **PENDING** (staging not live) |
| Live Hub pull against production gateway | **PENDING** (proof uses disposable mock upstream) |
| Penetration test | Not in this cycle |
