# CONFIG_AND_SECRET_MODEL.md

**Date:** 2026-08-02

## Classification

| Tier | Examples | Transfer default |
|------|----------|------------------|
| Public/nonsecret config | Version pins, non-sensitive feature flags, published URLs | Allowlisted yes |
| Host-local operational | Ports, container names (rewritten for staging) | Transform on apply |
| Secrets — platform | DB passwords for staging recreate; TLS keys for mig FQDN (Phase 18) | Controlled regenerate or scoped copy per OD |
| Secrets — third-party business | Payment PSP, customer SMTP vendor, external ERP connectors | **No automatic transfer** |
| Identity | Production device keys / slot material | **No** (Phase 20/21) |

## Staging rewrite

- Destination staging must not inherit Production public hostname as live identity  
- Secrets required for **technical validation** should be staging-scoped  

## Owner-pending destructive/sensitive

Any OD that enables bulk secret export is **Requires owner approval** and must be logged in transfer audit without printing secret values (`DATA_EGRESS_MODEL.md`).
