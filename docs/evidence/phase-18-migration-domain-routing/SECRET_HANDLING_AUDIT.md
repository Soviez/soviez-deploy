# SECRET_HANDLING_AUDIT

- Challenge values are signed tokens/hashes — not system-access secrets
- TLS private keys local-only; absent from inventories/status JSON
- DNS provider credentials never sent to SaaS (manual path; mock local)
- Device signing keys remain under device auth paths
