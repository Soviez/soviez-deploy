# E2E certification matrix

| ID | Scenario | Mode | Runtime | Mandatory |
|----|----------|------|---------|-----------|
| E2E-01 | Connected clean Production install → activate → domain/SSL → health → backup → restart | Connected | REAL_* | YES |
| E2E-02 | Manual and/or offline activation matrix | Mixed | REAL_* | YES |
| E2E-03 | Connected update + rollback proof | Connected | REAL_* + REGISTRY | YES |
| E2E-04 | Air-gapped offline update bundle | Air-gap | REAL_* + AIRGAP | YES |
| E2E-05 | Stage lifecycle (create→banner→retention path) | Connected/local | REAL_* | YES |
| E2E-06 | Backup → disposable destructive failure → restore | Local/remote dest | REAL_PG/ODOO | YES |
| E2E-07 | Existing Soviez → Soviez migration (same-product) | Connected | REAL_* | YES |
| E2E-08 | Source→dest migration with cutover + rollback | Connected | REAL_* | YES |
| E2E-09 | Security adversary matrix (unsigned/fake/replay/persist/secret) | Mixed | REAL + STATIC | YES |
| E2E-10 | SaaS outage / disconnected ERP survival | Offline SaaS | REAL_ODOO | YES |
| E2E-11 | Support expiry without ERP shutdown | Mixed | REAL_ODOO | YES |
| E2E-12 | Multi-tenant isolation | Connected | REAL_* | YES |

Pairwise OS coverage: Ubuntu 22.04 **and** 24.04 each appear in ≥1 mandatory install/update path; not every E2E×OS cell.
