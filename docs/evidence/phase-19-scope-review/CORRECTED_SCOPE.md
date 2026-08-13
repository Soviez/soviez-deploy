# CORRECTED_SCOPE.md

## Title correction

| | Text |
|---|------|
| **Older plan title** | Streaming migration |
| **Corrected title** | **Direct Streaming Migration, Resumable Transfer, and Destination Staging** |
| **Why rename** | Older title omitted **resumability**, **destination staging**, and the explicit **stop-before-token/activation** boundary. Corrected title names the three deliverables without implying cutover or token burn. |

## Corrected objective

Transfer selected business payloads (DB, filestore, registry-first addons, config classification, optional Stages) from an exact Phase 17–paired **ACTIVE** source to an **isolated non-Production destination staging** identity, using **direct** encrypted peer streaming with **chunk resume**, after Phase 18 routing readiness — **without** Migration Token reserve/consume, Production activation, public login, slot bind, or source deactivation.

## Inclusions

- Pre-migration Full backup gate (source VERIFIED; pin through 19–21)  
- Multi-pass pre-sync + short final write freeze (Option B)  
- Application-level mTLS chunked transfer service; resume registry  
- Transfer manifest + payload classification  
- DB final `-Fc` dump/apply to staging; filestore file-level chunked pre-sync  
- Addon registry-first transfer; config/secret classification  
- Explicit Stage select; expired excluded  
- Destination staging identity + technical validation (no public login)  
- Capacity, conflict, abort, reboot recovery, performance models  
- Token / License Guard / domain-routing **boundaries** (checks only)  
- Security + data-egress models; PASS/WARNING/BLOCKED ready-for-20 report  
- Docs and tests (when implementation authorized)

## Exclusions (later / never)

| Exclusion | Phase |
|-----------|-------|
| Migration Token reserve/consume | 20 |
| Source license deactivate / HMAC burn / rebind | 20 |
| Destination Production activation + public ERP login | 21 |
| Production DNS/traffic cutover | 21 |
| Source retention/archive/purge | 22 |
| WAL/PITR continuous replication | out of 19 |
| SaaS payload proxy / plain FTP / TOFU | never |
| Automatic third-party business credential transfer | never (default) |

## Binding future outcome (implementation acceptance banner)

```text
MIGRATION PAIR — VALID
ROUTING READINESS — INPUT OK
TRANSFER — COMPLETE (or resumable state recorded)
DESTINATION STAGING — READY
SOURCE — ACTIVE
MIGRATION TOKEN — NOT RESERVED / NOT CONSUMED
DESTINATION ERP PRODUCTION — NOT ACTIVATED
NO PUBLIC LOGIN — CONFIRMED
READY FOR PHASE 20 — PASS | WARNING | BLOCKED
```

## Boundary vs adjacent phases

- **← 16:** backup primitives + prerequisite Full  
- **← 17:** pair, trust, eligibility, bootstrap  
- **← 18:** domain/TLS/landing/routing readiness  
- **→ 20:** token integration only after Ready-for-20 PASS (or accepted WARNING)  
- **→ 21:** activation + cutover  
