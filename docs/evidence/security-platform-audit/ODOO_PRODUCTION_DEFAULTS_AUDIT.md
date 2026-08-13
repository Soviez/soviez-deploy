# Odoo production defaults audit

| Setting | Production | Result |
|---------|------------|--------|
| list_db | False | SAFE |
| dbfilter | set to tenant DB | SAFE-ish |
| admin_passwd | random 32 via CLI | SAFE (not empty/admin) |
| UI admin password | random 12 | SAFE — not admin/admin |
| username admin | fixed login name `admin` | CONDITIONAL (known username; password random) |
| proxy_mode | **missing** in tenant conf | UNSAFE/CONDITIONAL |
| workers/gevent | image defaults | UNKNOWN without image inspect |
| Database Manager | list_db=False reduces | SAFE for UI manager |

**Proof against default admin/admin:** ERP installer generates app password via secrets module (12-char) and sets via XML-RPC after install — not hardcoded `admin`/`admin`.
