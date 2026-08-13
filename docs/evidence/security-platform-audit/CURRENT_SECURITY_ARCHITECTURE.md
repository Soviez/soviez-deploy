# Current security architecture (source-mapped)

## Ownership split
| Surface | Current SoT |
|---------|-------------|
| Production `--init`/`--new` (Docker PG+ERP, Nginx, UFW, Fail2Ban, secrets) | `Soviez ERP/soviez.sh` (+ identical legacy `soviez-deploy/soviez.sh`) |
| Modular installer assemble/`dist` | `soviez-sh` |
| Stage/update/backup/migration/offline/security modules | `soviez-sh/src/*` |
| ERP application + ZATCA packs | `Soviez ERP/` addons |
| SaaS entitlements/Registry tickets | `soviez-saas` (UI frozen) |

## Production data path (ERP installer)
```text
Internet → :80/:443 (Nginx + UFW)
         → proxy_pass http://127.0.0.1:${SOVIEZ_HOST_PORT}
         → docker -p ${SOVIEZ_HOST_PORT}:8069  (binds all host interfaces by default)
         → ERP container on bridge network
         → Postgres container on same bridge (no -p publish)
```

## PostgreSQL
- Image init: `POSTGRES_USER=soviez` + random `SOVIEZ_DB_PASSWORD`
- No SQL `CREATE ROLE` / explicit `NOSUPERUSER` / revoke of `pg_execute_server_program`
- Official `postgres` image semantics: first `POSTGRES_USER` is a **superuser**

## Odoo defaults
- `list_db=False`, `dbfilter` set
- `admin_passwd` via `--admin-passwd` random 32-char
- UI login `admin` + random 12-char app password (not `admin`/`admin`)
- `proxy_mode` **not** set in production tenant conf

## Firewall
- UFW allow 22/80/443 then enable
- Fail2Ban sshd + nginx jails
- No DOCKER-USER / Docker-aware UFW integration observed

## What Phase 24 already hardened (orthogonal)
Signed updates, Registry ephemeral auth, secret scan, fake-sig quarantine, dist credential absence.
