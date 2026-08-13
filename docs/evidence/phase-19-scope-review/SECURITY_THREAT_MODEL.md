# SECURITY_THREAT_MODEL.md

**Date:** 2026-08-02

## Assets

Business DB/filestore; secrets; pair private keys; transfer resume registry; staging data; Migration Token eligibility metadata (not the burn itself).

## Threats & mitigations

| Threat | Mitigation |
|--------|------------|
| MITM / TOFU peer | Pair-pinned mTLS; no TOFU; SSH pinned fallback only |
| SaaS payload exfil relay | Ban SaaS proxy (`DATA_EGRESS_MODEL.md`) |
| Unauthorized transfer start | Pair + routing readiness + ops conflict + owner authz |
| Staging exposed as Production | No public login; no slot; isolation checks |
| Token burn via transfer bug | Hard boundary asserts `reserved/consumed=false` |
| Incomplete resume forgery | Chunk digests + manifest authenticity |
| Freeze sticky DoS | Hard timeout; auto release; reboot recovery |
| Gate bypass of pg_dump ban | Scoped authorized modules only; static gate update reviewed |
| Secret sprawl | No auto third-party business credential transfer |

## Non-goals this phase

Full Phase 24 hardening suite; threat model here scopes transfer/staging only.
