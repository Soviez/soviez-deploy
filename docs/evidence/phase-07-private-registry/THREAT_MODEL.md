# Threat model — Phase 7 Private Registry

**Scope:** Pull authorization foundation (SaaS + gateway). Installer wiring out of scope.

## Assets

| Asset | Location |
|-------|----------|
| Docker Hub pull credentials | Gateway env only |
| Ticket signing private key | SaaS env |
| Release manifest signing private key | SaaS env |
| Customer business data | Customer server (never in scope) |
| Pull tickets / client tokens | Short-lived client memory + temp docker config |
| Release catalog + sessions | Supabase Postgres |

## Threat actors

| Actor | Goal |
|-------|------|
| Unentitled customer | Pull private images without grant |
| Entitled customer A | Access customer B's pulls |
| External attacker | Steal Hub creds; push malicious images |
| Compromised client server | Exfiltrate or replay pull credentials |
| Insider | Publish unapproved release |

## Controls

| Threat | Control | Residual risk |
|--------|---------|---------------|
| Pull without entitlement | Device PoP + `private_image_pull` resolver | Stolen device key + valid grant |
| Cross-account session | RLS + account_id checks in service | Service-role misuse (ops) |
| Hub token theft from client | Never sent to client | Gateway env compromise |
| Ticket replay | Short TTL + jti hash tracking | Window ≤ 15 min post-refresh |
| Pull wrong image | Digest-only authority | Operator ignores verify step (installer must enforce) |
| Blob outside image | Session digest graph | Gateway restart loses graph (re-fetch manifest) |
| Push malicious image | Gateway denies writes | Hub account compromise (ops) |
| Catalog enumeration | Gateway denies catalog/tags | Known digest still required |
| Manifest tampering | Signed release manifest | Key compromise |
| SaaS outage stops ERP | ERP offline by design | N/A |
| Vercel blob abuse | No blob routes in Next.js | N/A |
| `:latest` confusion | Signing rejects latest | Legacy public pull unchanged |
| SQL injection / RLS bypass | Parameterized queries; deny policies | Implementation bugs |
| Log leakage | `redact.ts` in gateway | Misconfigured logging |

## Out of scope (deferred)

- Installer enforcement of temp config deletion (contract documented)
- Live Hub private repo ACL cutover
- WAF/rate limit on gateway (future ops)
- HSM key storage

## ERP runtime guarantee

**Running ERP never depends on registry/SaaS availability** — confirmed design constraint, not a network control.
