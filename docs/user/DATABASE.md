# Database

## Topology

PostgreSQL runs in Docker on an internal network. **Port 5432 must not be public.**

## Roles

| Role | Purpose |
|------|---------|
| Bootstrap/admin (`soviez_admin` default) | Provisioning only |
| App (`soviez_app` default) | ERP runtime least privilege |

## App role must NOT have

```text
SUPERUSER, CREATEROLE, CREATEDB, REPLICATION, BYPASSRLS
```

Dangerous server-file / `COPY PROGRAM` capabilities are denied and gated.

## Operator practice

- Prefer Soviez backup/restore commands over manual `pg_dump` for certified paths
- Untrusted SQL dumps enter quarantine
