# Architecture

## Planes

```text
Operator / Wizard / Modular CLI
        │
        ▼
Unified Operation Engine (persistent jobs, reattach)
        │
   ┌────┼────┬─────────┬──────────┐
   ▼    ▼    ▼         ▼          ▼
Install Stage Update  Backup    Migration
   │      │     │        │          │
   └──────┴─────┴────────┴──────────┘
                 │
         Security Platform (S1–S6)
                 │
     Docker · Nginx · PostgreSQL · Odoo
                 │
            Soviez SaaS (entitlements only)
```

## Dual installer model

| Artifact | Responsibility |
|----------|----------------|
| Dual wizard ERP≡deploy | Host `--init`, Production `--new`, Nginx/Docker provision |
| Modular `dist/soviez.sh` | Certified ops: Stage/update/backup/restore/migration/security/offline |

Do not implement a second engine for an owned concern — extend the owner module.
