# Security Architecture (Canonical)

Do not require reading six historical reports for current behavior. Evidence remains linked.

| Gate | Module | Role |
|------|--------|------|
| S1 | `security/platform` | PG least privilege, Odoo private, Docker |
| S2 | `security/platform` | Firewall, Nginx, SSH, Fail2Ban, Webmin detect |
| S3 | `security/detection` | DB/host/YARA/process IOC |
| S4 | `security/quarantine` | Restore/migration quarantine |
| S5 | `update_safety`, `backup_safety` | Update/backup/network/PDF/apt |
| S6 | tests + evidence | Integrated certification |

Historical: `docs/evidence/security-gate-s{{1..6}}/`.
