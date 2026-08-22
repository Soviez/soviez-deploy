# Soviez.sh Official Documentation

**Status:** CANONICAL / CONTRACT-ALIGNED  
**Canonical product contract:** [SOVIEZ_SH_PRODUCT_CONTRACT.md](SOVIEZ_SH_PRODUCT_CONTRACT.md)  
**Implementation matrix:** [IMPLEMENTATION_STATUS_MATRIX.md](IMPLEMENTATION_STATUS_MATRIX.md)  
**Platform build:** `0.24.6.3-platform-cli`  
**SHA256 (dist):** `43de932f2be866f245f2b0b694112c93e811054cd2ccd13fec21df0977897781`  
**Engineering:** 100% COMPLETE · **Security Platform:** CERTIFIED · **Release:** NOT AUTHORIZED

This tree describes Soviez.sh per the **owner-approved product contract**. Certified runtime behavior is distinguished from approved-but-not-yet-implemented features via the implementation matrix. Historical phase evidence lives under `docs/evidence/` and must not be treated as current operator documentation without checking supersession notes.

## Choose your audience

| Audience | Entry | Purpose |
|----------|-------|---------|
| **User / Operator** | [docs/user/README.md](user/README.md) | Install, operate, troubleshoot without reading source |
| **Developer / Maintainer** | [docs/dev/README.md](dev/README.md) | Architecture, ownership, internals, tests |
| **AI Engineering Agent** | [docs/ai/README.md](ai/README.md) | Mandatory read order, invariants, change protocol |
| **Security Reference** | [docs/security/](security/) | Security platform operator/reference docs |
| **Certification Evidence** | [docs/evidence/](evidence/) | Historical PASS packs (immutable) |

## Product surfaces

| Surface | Customer path | Role |
|---------|---------------|------|
| **Soviez.sh CLI (public)** | `/usr/local/bin/soviez.sh` | Single customer executable; operations, Stage, backup, restore, migration, security, tuning |
| **Dual Production wizard (internal/compatibility)** | `Soviez ERP/soviez.sh` | Interim host `--init` until modular PATH convergence; not a second public lifecycle |
| **SaaS backend** | `soviez-saas/` (Soviez-operated) | Entitlements, Registry tickets, offline issuance — not required for ERP runtime |

Customers must not use repository-relative paths or `dist/` artifacts. Do not use repo checkouts as the customer install path.

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
