# TRANSFER_PROTOCOL_MODEL.md

**Date:** 2026-08-02

## Primary protocol (**recommended**)

**Application-level mTLS chunked transfer service** bound to Phase 17 pair identity.

| Property | Default |
|----------|---------|
| Auth | Mutual TLS; pair-pinned certs; **no TOFU** |
| Transport | Encrypted stream; chunk framing + digests |
| Resume | Chunk resume registry (`CHUNKING_AND_RESUME_MODEL.md`) |
| Relay | **No SaaS proxy** of payloads |
| Compression | zstd balanced (OD) |
| Chunk size | Fixed initially; default **64 MiB** |
| Bandwidth profile | Balanced |

## Admin fallback

- **SSH** admin fallback only (break-glass / constrained environments)  
- Still pair-bound, logged, and non-TOFU (known_hosts / pinned host keys from pair)  
- Not the product default UX path  

## Explicit bans

- Plain FTP / anonymous drop zones as transport  
- Unauthenticated HTTP file push  
- Trust-on-first-use for peer identity  
- Using Phase 16 SFTP/S3 backup upload as the migrate protocol  

## Handshake prerequisites

1. Pair VALID  
2. Phase 18 routing readiness acceptable  
3. Capacity OK  
4. Transfer op conflict check PASS  
5. Source backup gate for final pass  

See `SECURITY_THREAT_MODEL.md`, `DATA_EGRESS_MODEL.md`.
