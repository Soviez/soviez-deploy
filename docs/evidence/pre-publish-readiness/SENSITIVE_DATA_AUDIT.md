# SENSITIVE_DATA_AUDIT

| Category | Finding | Action |
|----------|---------|--------|
| API/SaaS/Stripe/service-role keys in publish set | None confirmed in classified publish paths | Keep `.env*` excluded |
| Registry credentials | Not in publish set | — |
| PostgreSQL/Odoo master passwords | Only under `.tmp` | Exclude |
| Migration/activation tokens | `ticket.token`, offline package | Exclude |
| Private keys | `.tmp/**` migration trust keys | Exclude |
| Customer DB names | Appears in ERP CHANGELOG (Lugmety) — unrelated; do not publish with cycle | Exclude CHANGELOG delta |
| Live IPs | Not required in publish set | — |
| Production domains in docs | Public product domains (registry.soviez.com) OK as config defaults | OK |

Sensitive-data findings requiring exclusion before commit: **yes (root secrets + .tmp)**  
Sensitive findings inside intended publish manifest after exclusions: **0**
