# Update / network safety audit

Phase 24 update security = signatures/Registry/secrets — **not** network/firewall/port exposure gates.

Current update success often ≈ containers Up — insufficient for:
- firewall/Docker DNS/outbound
- Odoo→PG, Nginx→Odoo, domain→Nginx
- 8069/5432 public exposure checks
- wkhtmltopdf/PDF deps

Rollback exists for update packages; not for accidental public-port reintroduction.
