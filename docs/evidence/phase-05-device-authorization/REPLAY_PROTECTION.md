# Replay protection

- Table `device_request_nonces`
- Unique (device_id, nonce)
- TTL default 15 minutes
- Cleanup via `cleanup_device_auth_ephemera`
- Cryptographic nonce ≠ commercial idempotency key
