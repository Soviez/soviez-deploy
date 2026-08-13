# Real-runtime requirements

| Class | Meaning |
|-------|---------|
| REAL_RUNTIME_REQUIRED | Full product path on disposable host |
| REAL_POSTGRES_REQUIRED | Real PostgreSQL (not marker dump) |
| REAL_ODOO_REQUIRED | Real Soviez ERP/Odoo container runtime |
| REAL_DOCKER_REQUIRED | Real Docker engine |
| REAL_REGISTRY_REQUIRED | Real private Registry or exact local digest OCI |
| REAL_NETWORK_REQUIRED | Controlled network egress allowed |
| AIRGAP_REQUIRED | Deny-proxy / no outbound during apply |
| FIXTURE_ACCEPTABLE | Unit/adapter proofs only |
| STATIC_ONLY | Source/dist static gates |

## Minimum REAL_* for material E2E
clean install; activation; update; offline update; backup/restore; Stage; migration; rollback; security runtime; reboot/recovery.

**Rule:** marker-only certification is **forbidden** for material end-to-end flows.
