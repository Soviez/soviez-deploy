# PAYLOAD_CLASSIFICATION.md

**Date:** 2026-08-02

## Classes

| Class | Transfer in Phase 19? | Notes |
|-------|----------------------|-------|
| `db.production` | Yes (final `-Fc`) | Primary DB |
| `filestore.production` | Yes (chunked pre-sync + delta) | File-level |
| `addon.registry` | Yes | Registry-first pull/pin on dest |
| `addon.local_unmanaged` | Optional / WARNING | Owner policy; prefer registry |
| `config.nonsecret` | Yes (allowlisted) | Versions, feature flags, nginx stubs as allowed |
| `config.secret` | Classified; default **no auto third-party business credentials** | See `CONFIG_AND_SECRET_MODEL.md` |
| `stage.<id>` | Only if explicitly selected | Expired always excluded |
| `backup.offbox` | No (not migrate payload) | Prerequisite only |
| `saas.metadata` | Allowlist only | Non-sensitive; Sovereignty First |
| `token.material` | **No** | Eligibility check only |
| `license.slot` | **No** | Phase 20/21 |

## Required vs optional

- Production DB + filestore = **required** for Ready-for-20 PASS (unless OD narrows)  
- Stages = optional unless marked mandatory  
- Unmanaged addons / secrets = WARNING or skip per OD  

## Exclusion defaults

- Expired Stages  
- Third-party business credentials (API keys to customer SaaS vendors, payment PSPs, etc.) unless explicit OD  
- Source private device keys for Production identity reuse on dest Production (activation is Phase 21)
