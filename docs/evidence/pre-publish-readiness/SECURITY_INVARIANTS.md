# SECURITY_INVARIANTS

Reconfirmed as release/publication scope requirements (from certification; not re-executed live):

| Invariant | Status in publish scope |
|-----------|-------------------------|
| App PostgreSQL role non-superuser | Preserved in certified design |
| No public PostgreSQL | Preserved |
| No public Odoo backend | Preserved |
| No privileged app container | Preserved |
| No Docker socket mount | Preserved |
| No host networking | Preserved |
| No unsafe apt lock kill/rm | S5 correction in scope |
| Quarantine / update validation | In scope |
| No hidden telemetry / business-data egress | Sovereignty matrix certified |
| ZATCA immutability | Certified |
| Webmin/Virtualmin never installed by Soviez.sh | Certified |

No security invariant regression introduced by this audit (runtime unchanged).
