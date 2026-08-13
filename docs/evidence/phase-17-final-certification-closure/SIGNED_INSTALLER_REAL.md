# SIGNED_INSTALLER_REAL.md

**Result:** PASS  

Suite: `tests/integration/test_migration_signed_installer_real.sh`

Proven: exact version `0.17.0-phase17`; immutable checksum/digest; pinned trusted signer (HMAC + Device Ed25519); verify-before-execute; architecture validation; expiry; bad signature denied; wrong digest denied; untrusted signer denied; mutable `latest` not trusted; unsigned self-update absent; connected + offline package paths.
