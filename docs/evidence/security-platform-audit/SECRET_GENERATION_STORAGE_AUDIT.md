# Secret generation & storage audit

| Secret | Generation | Persistence | Exposure risks |
|--------|------------|-------------|----------------|
| SOVIEZ_DB_PASSWORD | secrets module random | host conf / docker env | docker inspect, logs if echoed |
| admin_passwd | random 32 | odoo CLI / conf | inspect/env |
| UI admin password | random 12 | DB only after set | operator display at install |
| Migration secrets | SOVIEZ_MIGRATION_SECRET | env/files | inspect |
| Registry | ephemeral Phase 24 | tickets | Phase 24 hardened |
| Device/License | License Guard paths | local | Phase 24 scan |
| Backup encryption | if configured | backup meta | inventory incomplete for all providers |

Weak/predictable: staging fixtures `odoo`/`odoo` — HIGH if misused as Production.
No derivation from hostname/time alone observed for Production secrets.
