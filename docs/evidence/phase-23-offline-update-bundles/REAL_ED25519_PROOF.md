# REAL_ED25519_PROOF

Suite: `tests/integration/test_phase23_real_ed25519.sh`

Requires `SOVIEZ_OPENSSL` OpenSSL 3 (Homebrew) — LibreSSL lacks ED25519.
Proves real detached Ed25519 signatures for bundle path and tamper/wrong-purpose rejection under certification flags.
