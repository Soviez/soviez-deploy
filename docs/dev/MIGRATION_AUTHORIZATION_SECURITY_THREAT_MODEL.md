# Migration Authorization Security Threat Model

## Assets

- Migration token grants (`commercial_grants.migration_token`)
- License binding (fingerprint, DB UUID, digest)
- Signed authorization receipts
- Idempotency keys and request hashes
- Offline authorization packages

## Trust boundaries

| Boundary | Trust |
|----------|-------|
| SaaS `commit_migration_authorization` | Authoritative commercial SoR |
| Installer local state | Untrusted until verified against signed receipt |
| Offline package | Trusted only with valid signature + replay registry |
| Legacy consume paths | Untrusted — blocked |

## Threats and mitigations

| Threat | Mitigation |
|--------|------------|
| Double token consume | Atomic commit + idempotency; one committed auth per license |
| Split-brain dual public | `split_brain_validate`; `public_route=false` enforced |
| Unauthorized cutover/DNS | Static gates; `MIGRATION_CUTOVER_NOT_AUTHORIZED` |
| Legacy bypass consume | `consume_ip_migration_token` raises; installer blocks `SOVIEZ_MIG_LEGACY_CONSUME` |
| Idempotency confusion attack | Same key different hash → `IDEMPOTENCY_CONFLICT` |
| Offline replay | `offline_replay` registry; package expiry |
| Token invention locally | Eligibility reads ledger only; no local mint |
| Grant/wallet desync | `MIGRATION_TOKEN_LEDGER_INCONSISTENT` blocks commit |
| SaaS payload relay | `MIGRATION_DATA_EGRESS_DENIED` |
| Unauthorized compensation | Admin-only reversal; audit tables immutable |
| Multi-tenant cross-account | Account-scoped locks and idempotency keys |

## Adversary classes

1. **Malicious destination host** — cannot consume without valid grant + matching fingerprints.
2. **Replay attacker** — blocked by idempotency and offline replay registry.
3. **Rogue operator env flags** — cutover/DNS/purge flags die at gate.
4. **Network MITM on commit** — recover via idempotency; no blind retry consume.

## Secret handling

- Authorization objects contain **no private keys** (`no_private_keys=true` on offline packages).
- Request hash binds payload integrity; public signature on receipts.

## Certification evidence

See `docs/evidence/phase-20-atomic-authorization-rebind/SECURITY_ADVERSARY_MATRIX.md` and `SECRET_HANDLING_AUDIT.md` (pending run).
