# C1 correction — PG SUPERUSER

**Before:** POSTGRES_USER=soviez used as Odoo app role → image SUPERUSER.

**After:** Bootstrap  (POSTGRES_USER) + app  with NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS. Odoo connects only as soviez_app. Bootstrap password never in Odoo env.
