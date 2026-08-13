# Rollback architecture

Mutable controls: snapshot UFW/DOCKER-USER rules, compose/run flags, odoo.conf, role DDL before change; validate; rollback on connectivity fail.

**Never auto-rollback:** weak passwords, known compromised credentials, known malicious DB records, revoked secrets.
