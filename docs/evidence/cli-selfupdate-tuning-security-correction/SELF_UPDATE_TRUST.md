# Trust model

- Manifest URL default: `https://raw.githubusercontent.com/Soviez/soviez-deploy/main/platform-release/<channel>/manifest.json`
- Overrides: `SOVIEZ_PLATFORM_MANIFEST_URL` / `SOVIEZ_PLATFORM_MANIFEST_FILE`
- Required fields: `version`, `sha256`, `artifact_url`, `signed=true`, `signature`
- SHA256 fail-closed
- Optional Ed25519 via `SOVIEZ_PLATFORM_TRUST_PUBKEY` + existing `soviez_security_*` hooks
- **Connected production metadata must be published before wild self-update works** (not published in this cycle)
