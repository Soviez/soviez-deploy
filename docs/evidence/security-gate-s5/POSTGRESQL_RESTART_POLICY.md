# POSTGRESQL_RESTART_POLICY

Postgres container/service restart after host/package change must re-validate Odoo↔PG and published-port protection. No public 5432 regression allowed. Covered by Docker restart matrix + DB checks: PASS.
