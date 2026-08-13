# Docker security audit

| Control | Production ERP installer | Notes |
|---------|--------------------------|-------|
| `--link` / `links:` | **ABSENT** | Positive |
| Host networking | Not used for ERP/PG | |
| Privileged containers | **ABSENT** | Positive |
| Docker socket mounts | **ABSENT** on app/DB | Positive |
| User-defined bridge | Yes (`NETWORK_NAME`) | Shared ERP+PG |
| Published ports | ERP 8069→host all-ifaces; PG none | See Odoo exposure |
| Writable host mounts | Data/addons/config dirs | Expected |
| Secrets in env | Yes (PG password, etc.) | Inspect-visible |
| Restart | unless-stopped typical | |
| Cap-drop / non-root | Not observed for ERP image | MEDIUM |

Inter-container trust: any container on same bridge can reach PG:5432 with credentials.
