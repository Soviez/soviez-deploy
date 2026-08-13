# Registry authorization flow

SaaS is entitlement SoT. Gateway is enforcement.

Ticket format: `base64url(canonical_json).base64url(ed25519_sig)` domain `soviez.registry-pull-ticket.v1`.
TTL: 900s credential / 3600s session max.
Scope: `pull` only. Repository allowlist includes `soviez/soviez-erp`.
