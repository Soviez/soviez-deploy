# TRUST_PAIRING_AND_MTLS_REAL.md

**Result:** PASS  

Suite: `tests/integration/test_migration_mtls_real.sh`

Proven: real Device Ed25519 identities; openssl-issued pair certificates; exact source/destination/License binding; one-time bootstrap code; signed challenge/response; owner fingerprint confirmation; `SOVIEZ_MIG_MTLS_LOOPBACK=1` real handshake (`ok-handshake`); expiry/revocation/replay denials; wrong source/destination/License denial; CA substitution / MITM denial; no shared permanent password; private keys stay in protected local files.
