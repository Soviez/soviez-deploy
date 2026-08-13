# Cryptographic protocol

- Ed25519 raw 32-byte public keys (base64url)
- Domain: `soviez.device-auth.v1`
- Fingerprint: SHA-256(raw) first 32 hex grouped
- device_code: 32-byte hex; stored hashed
- user_code: Crockford-like XXXX-XXXX; stored hashed
- Credential: opaque `svc_*` random; SHA-256 at rest
- Token PoP: sign token-proof message
- Request PoP: canonical request + domain prefix
- Separate from license signing / migration HMAC / Stripe secrets
