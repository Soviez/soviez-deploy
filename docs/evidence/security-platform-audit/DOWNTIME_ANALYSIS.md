# Downtime analysis

| Action | Class |
|--------|-------|
| Security check/scan/report | NO_DOWNTIME |
| PG role NOSUPERUSER revoke | CONTROLLED_RESTART (Odoo reconnect) / MAINTENANCE if recreate role |
| Docker network / port rebind | CONTROLLED_RESTART |
| Firewall DOCKER-USER | RELOAD_ONLY (validate) |
| Odoo proxy_mode conf | CONTROLLED_RESTART |
| SSH harden | OPERATOR_INTERACTION_REQUIRED |
| Nginx/TLS header tweaks | RELOAD_ONLY |
| Monitoring agent install | NO_DOWNTIME→RELOAD |
| Backup off-host enable | NO_DOWNTIME |
| Migration quarantine | MAINTENANCE_WINDOW |
| Full PG role redesign with new user | MIGRATION_REQUIRED |
