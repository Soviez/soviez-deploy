# Security severity policy

CRITICAL / HIGH / MEDIUM / LOW / INFO

Deployment security certification **FAIL** on CRITICAL examples:
- Odoo DB role SUPERUSER
- pg_execute_server_program / server file roles
- PostgreSQL public
- Unexpected Odoo direct public exposure
- Known malicious DB IOC / active executable server action
- Default/known weak admin credential
- Privileged app container / docker.sock in app
- TLS absent where Production requires

Not every scanner finding is CRITICAL.
