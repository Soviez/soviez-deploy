# OFFLINE_INDEPENDENCE — Gateway Offline Ticket Verification

## Verdict

**PASS** (design + unit tests)

## Principle

Registry gateway verifies pull tickets **offline** using configured Ed25519 public keys. No live SaaS round-trip is required per manifest/blob request.

## Offline verification chain

```
Pull ticket (client-presented)
    → base64url decode claims + signature
    → verify Ed25519 with SOVIEZ_REGISTRY_TICKET_PUBLIC_KEYS_JSON
    → check exp, scope, repository, digest bindings
    → authorize proxy (no SaaS call)
```

## SaaS dependency boundary

| Phase | SaaS required? |
|-------|----------------|
| Ticket issuance / refresh | **YES** |
| Per-pull manifest/blob at gateway | **NO** |
| Session revoke (optional hard stop) | SaaS DB only; gateway honors ticket TTL |

## Public key source

Gateway env: `SOVIEZ_REGISTRY_TICKET_PUBLIC_KEYS_JSON` — JSON map of `rtk_*` → raw pubkey.

Key rotation: update map on gateway; no code deploy required for new pubkey addition.

## Installer offline bundle

Offline packages may include `ticket_token` + public keys for stage operations without live authorize — separate from gateway offline verify path. Root `offline-package.json` excluded from git (PP-03).

## Registry outage vs SaaS outage

| Outage | Effect |
|--------|--------|
| SaaS down after ticket issued | Pull continues until ticket `exp` (≤900s) |
| Gateway down | Pull fails; installer may retry / use cached images if present |
| Hub down | Gateway cannot proxy; client sees upstream errors |

See also `REGISTRY_OUTAGE_RUNTIME_INDEPENDENCE.md`.

## Test evidence

All gateway tests run with local keypair + mock upstream — no network SaaS dependency. **20/20 PASS**
