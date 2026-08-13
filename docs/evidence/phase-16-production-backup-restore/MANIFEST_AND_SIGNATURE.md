# Manifest and signature
Canonical JSON + HMAC-SHA256 with local `manifest.key`.
Verify fails on tamper. Forbidden secret field names scrubbed before sign.
