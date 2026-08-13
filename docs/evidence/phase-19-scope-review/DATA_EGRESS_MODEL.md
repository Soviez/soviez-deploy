# DATA_EGRESS_MODEL.md

**Date:** 2026-08-02  
**Aligns with:** `docs/ai/DATA_EGRESS_CONTRACT.md` (streaming remains unauthorized until impl)

## Allowed egress (Phase 19 design)

| Path | Payload |
|------|---------|
| Source → Destination peer (mTLS) | Classified transfer payloads only |
| Destination → Registry | Addon digest pulls (registry-first) |
| Both → SaaS | Non-sensitive ops/eligibility metadata allowlist only — **no DB/filestore** |

## Forbidden egress

- SaaS (or any third party) as **payload relay** for migration bytes  
- Unencrypted / FTP / anonymous upload of business data  
- Automatic export of third-party business credentials  
- Telemetry containing dump contents or secret values  

## Logging

- Log transfer_id, counts, digests, errors — **redact** secrets  
- No PII in URLs  

Phase 20 HMAC receipts remain out of scope; do not implement burn side-channels here.
