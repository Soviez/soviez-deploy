# Critical defects (source-proven)

## C1 — Odoo application DB role is PostgreSQL SUPERUSER (by image semantics)
- **Evidence:** `Soviez ERP/soviez.sh` starts Postgres with `POSTGRES_USER=soviez`; ERP connects as `soviez` with same password; no `ALTER ROLE … NOSUPERUSER` / no least-privilege app role.
- **Official postgres image:** `POSTGRES_USER` is created as superuser.
- **Impact:** Compromised Odoo admin / malicious `ir.actions.server` / SQL path → host OS as postgres user via server-side program execution class (`COPY … PROGRAM` / related privileges).
- **Class:** **UNSAFE** — maps directly to incident boundary `COMPROMISED ODOO ⇏ COMPROMISED PG HOST` failure.
- **Root cause:** Production provision treats image bootstrap user as app role.

## C2 — Odoo HTTP published on all host interfaces
- **Evidence:** `docker run … -p "${SOVIEZ_HOST_PORT}:8069"` (no `127.0.0.1:` prefix) in `Soviez ERP/soviez.sh` (~2095) and Stage (~5380).
- **Impact:** Direct Odoo exposure on `0.0.0.0:HOST_PORT` even when Nginx is intended edge. Docker often inserts ACCEPT rules that **bypass UFW** for published ports.
- **Class:** **UNSAFE** for “no unintended public direct Odoo exposure”.
- **Root cause:** Host-port publish used for Nginx localhost proxy without loopback bind.

## C3 — No platform gate that FAIL-closes on C1/C2
- **Evidence:** No `soviez-sh` / ERP installer validation asserts NOSUPERUSER, denies `pg_execute_server_program`, or fails if 8069-class ports are globally published.
- **Impact:** Defects persist across `--new` / Stage / rebuild without detection.
- **Class:** **UNSAFE** (missing critical containment certification).

Note: These are **not** assumed from the external Odoo incident; they are mapped from Soviez production installer source + postgres image semantics.
