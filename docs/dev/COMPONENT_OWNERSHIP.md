# Component Ownership

**Rule:** one owner per concern. Do not create parallel engines.

| Concern | Owner path |
|---------|------------|
| CLI parse/dispatch | `src/cli/parse.sh`, `src/entrypoint.sh` |
| New activation | `src/commands/new.sh` |
| Stage | `src/stage/`, `src/commands/stage*.sh` |
| Update | `src/update/` |
| Offline update | `src/offline_bundle/`, `src/offline_update/`, `src/offline_trust/` |
| Backup | `src/backup/` |
| Restore | `src/restore/` |
| Migration | `src/migration/` |
| Ops engine | `src/operations/`, `src/ops/` |
| Security S1–S2 platform | `src/security/platform/` |
| Detection S3 | `src/security/detection/` |
| Quarantine S4 | `src/security/quarantine/` |
| Update/backup safety S5 | `src/security/update_safety/`, `src/security/backup_safety/` |
| Nginx (modular) | `src/nginx/`, S2 `nginx_edge.sh` |
| Nginx (Production wizard) | `Soviez ERP/soviez.sh` `write_nginx_site` |
| Database provision | `src/database/`, ERP wizard PG run |
| Entitlement client | `src/entitlement/`, `src/api/` |
| Registry **client** (ticket → temp Docker auth → digest pull → cleanup) | `src/registry/`, `src/api/registry_client.sh` |
| Registry Gateway **server** (internal Soviez-operated) | Local `soviez-registry-gateway/` — **not** published in `Soviez/soviez-deploy` |
| SaaS authority | `soviez-saas/` |

AI agents: read this before adding features.
