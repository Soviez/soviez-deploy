# Networking

**Version:** `0.24.5.1-security-s5-corr1`

## Topology (Production)

```text
Internet clients
    │
    ▼
Nginx :80 / :443  (PUBLIC)
    │  proxy_pass http://127.0.0.1:<HOST_PORT>
    ▼
Odoo HTTP container port 8069  (LOOPBACK host publish only)
    │
    ▼
PostgreSQL :5432  (DOCKER-INTERNAL only — never public)
```

## Port classification

| Port | Purpose | Binding | Exposure |
|------|---------|---------|----------|
| 22 | SSH | Host | PUBLIC (management) |
| 80 | HTTP/ACME | Nginx | PUBLIC |
| 443 | HTTPS | Nginx | PUBLIC |
| 8069 | Odoo HTTP | Container; host `127.0.0.1:HOST→8069` | **LOOPBACK / not public Production endpoint** |
| 8071 | Policy watch only | Not published by current generators | **BLOCKED** if appear public |
| 8072 | Classic gevent port | Not published by current generators | **BLOCKED** if appear public |
| 5432 | PostgreSQL | Docker network | **DOCKER-INTERNAL / never public** |
| 10000 | Webmin (if pre-existing) | Not opened by Soviez | Detect/classify only |

Host loopback publish ports for tenants typically start at **8073+** mapping to container **8069**.

## Explicit rules

```text
8069 is not intended as a public Production endpoint.
5432 must not be public.
```

Do **not** "fix" WebSocket by publishing 8069/8072 publicly.

## Quarantine / Stage / offline

- Quarantine uses restricted networking (S4).
- Stage uses separate containers/domains; same private-backend policy.
- Offline hosts still use local Nginx/Odoo/PG topology without SaaS.
