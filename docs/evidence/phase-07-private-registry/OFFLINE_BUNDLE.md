# Offline bundle — Phase 7

## Format

**Version:** `offline-image-bundle/v1`

Implementation: `soviez-saas/src/lib/registry/offline-bundle.ts`

## Manifest structure

| Field | Purpose |
|-------|---------|
| `format_version` | Must be `offline-image-bundle/v1` |
| `product_code`, `release_id`, `release_version`, `channel` | Identity |
| `repository`, `digest`, `architecture` | Pull authority mirror |
| `archive_format` | `oci-layout` or `docker-archive` |
| `archive_checksum_sha256` | SHA-256 of archive file |
| `archive_relative_path` | Path within bundle directory |
| `signed_release_manifest` | Embedded signed release manifest |
| `signer_key_id` | Release manifest key |
| `min_installer_version` | Optional gate |
| `entitlement_package_ref` | Optional future cross-ref |
| `created_at` | ISO8601 |

## Verification pipeline

`verifyOfflineBundleManifest(bundle, opts)`:

1. Format version check
2. Reject if serialized content contains private key patterns
3. Require `signed_release_manifest.signature_b64url`
4. Validate digest format
5. Optional `expectedDigest` / `expectedArchitecture` match
6. `verifyReleaseManifest` on embedded manifest
7. Cross-check manifest payload digest/arch vs bundle fields
8. Optional: `archiveBytes` SHA-256 vs `archive_checksum_sha256`

## Failure reasons

`malformed`, `digest_mismatch`, `architecture_mismatch`, `checksum_mismatch`, `manifest_invalid`, `format_unsupported`, `missing_signature`, `private_key_present`

## CI artifact input

Prep workflow exports:

- `artifacts/soviez-erp.oci.tar`
- `artifacts/soviez-erp.oci.tar.sha256`
- `artifacts/release-candidate.json`

Future phases wire bundle assembly + distribution.

## Sovereignty

- Verification requires **public keys only**
- No SaaS or Hub call at verify time
- Full installer import deferred (Phase 23 area)

## Tests

- `logic.test.ts`: build + verify roundtrip, digest mismatch, missing signature
