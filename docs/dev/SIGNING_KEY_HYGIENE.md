# Signing Key Hygiene

- Public key fingerprint: `soviez_security_pubkey_fingerprint` → `sha256:` of SPKI/DER (or PEM bytes)
- Secrets written via `soviez_tenant_secret_write` get `*.sha256` sidecars
- Private key modes must be `600` or `400` (`soviez_security_assert_private_key_perms`)
- Production dist may contain public trust material only — never private signing keys
