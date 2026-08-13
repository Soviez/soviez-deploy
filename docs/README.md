# Soviez.sh Official Documentation

**Status:** CANONICAL / CODE-SYNCHRONIZED  
**Certified installer:** `0.24.5.3-registry-gateway`  
**SHA256:** `68ab59972d84d34f38c43862ca28946d3df3da5707fefa970230bd43e1da3460`  
**Engineering:** 100% COMPLETE · **Security Platform:** CERTIFIED · **Release:** NOT AUTHORIZED

This is the **official Source of Truth** for Soviez.sh. It describes what the code and certified tests do **now**. Historical phase evidence lives under `docs/evidence/` and must not be treated as current operator documentation.

## Choose your audience

| Audience | Entry | Purpose |
|----------|-------|---------|
| **User / Operator** | [docs/user/README.md](user/README.md) | Install, operate, troubleshoot without reading source |
| **Developer / Maintainer** | [docs/dev/README.md](dev/README.md) | Architecture, ownership, internals, tests |
| **AI Engineering Agent** | [docs/ai/README.md](ai/README.md) | Mandatory read order, invariants, change protocol |
| **Security Reference** | [docs/security/](security/) | Security platform operator/reference docs |
| **Certification Evidence** | [docs/evidence/](evidence/) | Historical PASS packs (immutable) |

## Product surfaces (do not confuse)

| Surface | Path | Role |
|---------|------|------|
| **Modular installer (canonical artifact)** | `soviez-sh/dist/soviez.sh` | Certified operations CLI (update, Stage, backup, restore, migration, security, offline) |
| **Dual Production wizard (supported)** | `Soviez ERP/soviez.sh` ≡ `soviez-deploy/soviez.sh` | Host bootstrap `--init`, Production `--new`, Nginx/Docker provisioning |
| **SaaS backend** | `soviez-saas/` | Entitlements, Registry tickets, offline issuance, migration authorization (UI frozen) |

## Quick facts

- ERP runtime does **not** require continuous SaaS connectivity.
- Support expiry does **not** stop ERP.
- Stage entitlement expiry does **not** stop or delete existing Stages.
- `LOCAL_ONLY` backup = backup available, **not** disaster recovery.
- Soviez.sh **NEVER installs Webmin or Virtualmin**.
- Source purge is **never automatic**.
- Engineering complete ≠ release authorized.

## Navigation aids

- [Documentation coverage matrix](DOCUMENTATION_COVERAGE_MATRIX.md)
- [Documentation inventory](DOCUMENTATION_INVENTORY.md)
- [Conflict report](DOCUMENTATION_CONFLICT_REPORT.md)
- [Canonicalization evidence](evidence/documentation-canonicalization/)

## Registry Gateway

- [REGISTRY_GATEWAY.md](user/REGISTRY_GATEWAY.md)
- [PRIVATE_IMAGE_DELIVERY.md](user/PRIVATE_IMAGE_DELIVERY.md)
- [Architecture](dev/REGISTRY_GATEWAY_ARCHITECTURE.md)
