# Signed release manifest — Phase 7

## Domain separation

| Artifact | Signing domain | Type field |
|----------|----------------|------------|
| Release manifest | `soviez.release-manifest.v1` | `soviez.release-manifest.v1` |
| Pull ticket | `soviez.registry-pull-ticket.v1` | `soviez.registry-pull-ticket.v1` |
| Device auth (Phase 5) | `soviez.device-auth.v1` | — |

Domains are intentionally distinct to prevent cross-protocol signature replay.

## Canonical signing

```
signed_bytes = UTF-8( "soviez.release-manifest.v1\n" + canonical_json(payload) )
signature = Ed25519_sign(private_key, signed_bytes)
```

**Canonical JSON:** recursively sort object keys; arrays preserve element order.

## Payload fields

| Field | Required | Notes |
|-------|----------|-------|
| `type` | Yes | Must equal `soviez.release-manifest.v1` |
| `release_id` | Yes | UUID |
| `product_code` | Yes | |
| `release_version` | Yes | Must not be `latest` |
| `channel` | Yes | |
| `repository` | Yes | Must not contain `:latest` |
| `digest` | Yes | `sha256:[64 hex]` |
| `architecture` | Yes | |
| `platform_os`, `platform_arch` | Optional | |
| `is_index` | Optional | Multi-arch index |
| `min_installer_version` | Optional | |
| `build_at` | Optional | |
| `issued_at` | Yes | ISO8601 |
| `expires_at` | Optional | |
| `withdrawn` | Optional | If true, verify fails |
| `signer_key_id` | Yes | e.g. `rmk_<hash prefix>` |

## Verification

`verifyReleaseManifest(signed, publicKeysById)` returns:

- `ok: true` + payload, or
- `ok: false` + reason: `malformed`, `unknown_key`, `signature_invalid`, `digest_invalid`, `withdrawn`, `type_mismatch`

## Key management

| Env (SaaS) | Purpose |
|------------|---------|
| `SOVIEZ_RELEASE_MANIFEST_PRIVATE_KEY` | Sign at resolve / CI |
| `SOVIEZ_RELEASE_MANIFEST_PUBLIC_KEYS_JSON` | Verify (installer future) |

Key IDs: `rmk_<sha256(raw_pubkey)[0:16]>`

## Tests

- Sign/verify roundtrip (`logic.test.ts`)
- Rejects invalid digest
- Rejects `:latest` version/repo at sign time
- Domain string mismatch fails verify
