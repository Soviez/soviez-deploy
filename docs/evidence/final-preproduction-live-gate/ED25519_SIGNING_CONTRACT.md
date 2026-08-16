# ED25519_SIGNING_CONTRACT

- schema: soviez.platform_release.v1
- signature_algorithm: ed25519
- canonical payload: JSON without signature/signature_b64url/signed/signed_at; sort_keys True; compact separators; UTF-8; no trailing newline
- signature: raw 64-byte Ed25519 as base64url without padding
- verify: openssl pkeyutl -verify -pubin -rawin
- candidate sha256 and embedded version must match manifest
- cert staging manifest: https://raw.githubusercontent.com/Soviez/soviez-deploy/cert/0.24.6.1-platform-cli/platform-release/staging/manifest.json
