# Stage architecture

See [SOVIEZ_SH_PRODUCT_CONTRACT.md](../SOVIEZ_SH_PRODUCT_CONTRACT.md) §12.

## Isolation

Each Stage is isolated from Production: separate Odoo, PostgreSQL, network, storage, Nginx mapping, domain, SSL.

**Resource limits** (CPU, RAM, PID, I/O where practical) ensure a failing Stage cannot exhaust Production.

Production always has priority in sizing.

## Retention

| Rule | Value |
|------|-------|
| Default retention | 14 calendar days |
| Absolute maximum | 60 calendar days from creation |

Before auto-delete: final backup + Safe Shield. If protection fails → preserve Stage, mark **Needs Action**.

## Entitlement expiry

Blocks create/clone/refresh/rebuild. Does **not** immediately stop or delete existing Stages.

## Lifecycle

create, clone, refresh, rebuild, start, stop, status, backup, delete — see [IMPLEMENTATION_STATUS_MATRIX.md](../IMPLEMENTATION_STATUS_MATRIX.md).
