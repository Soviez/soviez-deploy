# MAINTENANCE_LANDING_MODEL.md

## What it is

A **neutral operational page** on the destination host — **not** the destination ERP, **not** a login portal, **not** a data plane.

Approved content only: migration-in-progress status; safe next step; retry guidance; support contact; request/operation ID where safe. **No** customer data, ERP login, DB access, source credentials, tracking, analytics, external fonts, or third-party scripts.

## Where it runs

- Destination host only  
- Isolated process/container or static root served by **Nginx** (mandatory initial proxy)  
- Separate Nginx `server_name` = migration subdomain  
- Upstream = landing only (static or tiny local server) — **never** Odoo port  

## When externally reachable

| Mode | Phase 18 default |
|------|------------------|
| Prepared & testable on destination (loopback / private) | Yes |
| Public via dedicated migration subdomain after DNS+TLS | **Yes** (owner OD-28 default allow) |
| Attached to customer Production domain | **No** — Phase 21 |

## Signature / provenance

Landing bundle hash recorded in operation state; optional Device-signed manifest. Content is static templates with escaped placeholders only.

## Security / a11y / cache

- Security headers: CSP (default-src 'none'; img/style/font self or none), `X-Content-Type-Options`, `Referrer-Policy`, `frame-ancestors 'none'`  
- No open redirects; Host header must match exact migration FQDN  
- Cache: short or no-store for status; static assets immutable if any  
- Rate-limit health vs page  
- Health: `GET /healthz` → 200 JSON `{ok:true}` no secrets  
- Logs: access minimal; no query PII; retention local OD  
- Accessibility: semantic HTML, contrast, English-only this stage (OD-16)  
- Localization boundary: English strings only until owner expands  

## Process model

Temporary by default (removed/disabled on Abort). Permanent landing container **not** required.
