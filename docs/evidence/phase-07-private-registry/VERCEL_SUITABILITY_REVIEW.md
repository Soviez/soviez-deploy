# Vercel suitability review — OCI blob proxy

**Verdict:** **NOT SUITABLE** for multi-GB OCI blob proxy. Separate Node gateway required.

**Date:** 2026-07-30

## Requirement

Proxy Docker Registry v2 blob downloads (individual layers often 100 MB–2 GB+) with:

- Streaming (no full-buffer in memory)
- HTTP Range / partial content support
- Concurrent pulls during install
- Pull-only authorization enforcement per session

## Vercel / Next.js constraints

| Constraint | Impact on OCI proxy |
|------------|---------------------|
| **Serverless function body size limit** | Cannot accept or return multi-GB request/response bodies through standard API routes |
| **Execution duration limits** | Long-running blob streams exceed typical function timeouts |
| **Memory limits** | Buffering even a single large layer risks OOM |
| **Bandwidth / egress economics** | Every layer byte would traverse serverless egress twice (Hub→Vercel→client) |
| **Cold start + connection churn** | Poor fit for persistent streaming connections |
| **Edge runtime** | No Node `http` streaming proxy to arbitrary upstream |

## What SaaS correctly handles on Vercel

- JSON API requests (resolve, session create/refresh/complete/revoke)
- Ed25519 ticket signing (milliseconds, small payload)
- Postgres session state via Supabase service role
- Capability entitlement resolution

**Blob path length:** 0 bytes through Next.js in Phase 7 design.

## Gateway fit

Node `http` server with:

- `pipeline(upstreamRes, clientRes)` streaming
- Range header forwarding
- Content-Length / Content-Range preservation
- Dedicated long-lived process (not serverless)

## Decision record

Documented in `ARCHITECTURE_DECISION.md`. Implementation: `soviez-sh/services/registry-gateway/`.

## Regression guard

No route under `soviez-saas/src/app/api/` proxies `/v2/` blob paths. Gateway is separate deployable.
