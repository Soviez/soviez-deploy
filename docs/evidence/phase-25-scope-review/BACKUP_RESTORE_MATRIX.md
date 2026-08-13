# Backup / restore matrix

| Path | Class | Phase 25 |
|------|-------|----------|
| Local full backup | REAL_* | Mandatory |
| S3-compatible | REAL_NETWORK if profile available | Mandatory if destination certified; else WARNING documented |
| SFTP | same | same |
| Encryption + checksums | REAL | Mandatory |
| Restore + verification | REAL_PG/ODOO | Mandatory |
| Destructive disposable failure → restore | REAL | E2E-06 |
| Full ERP restore depth (D24-11) | REAL | **Must close WARNING or OD-waiver** |

No protected-operation bypass.
