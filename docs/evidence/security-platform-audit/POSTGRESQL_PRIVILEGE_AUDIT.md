# PostgreSQL privilege audit

## Production path (`Soviez ERP/soviez.sh`)
| Attribute | Result |
|-----------|--------|
| Role name | `soviez` via `POSTGRES_USER` |
| Existing-role handling | Image volume reuse; no explicit SQL role reconcile |
| SUPERUSER | **UNSAFE** — image bootstrap user is superuser; no NOSUPERUSER revoke |
| CREATEROLE / CREATEDB / REPLICATION / BYPASSRLS | Inherited with superuser; not explicitly constrained |
| `pg_execute_server_program` | **UNSAFE / CONDITIONAL** — superuser implies dangerous server program capability class |
| `pg_read_server_files` / `pg_write_server_files` | Same |
| Schema/DB ownership | App DB created via Odoo `-i` as this user |
| Migration/restore elevation | Uses same privileged user; no temporary escalate→revert pattern |
| Odoo creates DBs | Yes (Odoo maintenance create path) — requires CREATEDB-class power today |
| Database Manager | `list_db=False` mitigates UI manager; does not reduce PG role power |

## Classification
```text
Odoo application role privilege model = UNSAFE
COPY PROGRAM escalation possibility = YES (via superuser)
Dangerous predefined role membership = EFFECTIVE YES (superuser)
```

## soviez-sh
No production SQL least-privilege implementation. Staging uses `POSTGRES_USER=odoo` (also image superuser semantics) with password `odoo`.
