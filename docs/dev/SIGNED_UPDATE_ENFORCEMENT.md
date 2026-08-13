# Signed Update Enforcement

Production path: `soviez_update_release_assert` → `soviez_security_require_signed_manifest` → `soviez_security_assert_manifest_crypto`.

Defaults: `SOVIEZ_UPDATE_STRICT_SIG=1`. Soft default-off removed.

Fake signatures (`ok`, `fixture`, short tokens, etc.) are denied unless disposable test bypass is allowed.
