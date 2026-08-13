# Non-negotiable rules

Extracted from PRODUCT_CONSTITUTION.md. Full list there.

Highlights:
1. Sovereignty First — user-initiated online only; disclose metadata; no business egress.
2. Runtime independence — add-on expiry never stops Production or existing Stages.
3. Provider-neutral grants — never Stripe-only entitlement logic.
4. License-scoped entitlements — no account-level fallback for Stage/updates. Strict resolver (`product_updates`, `stage_environments`) requires exact `licenses.id`.
5. `--update` requires exact one Production tenant.
6. Domain+SSL mandatory for Production and Stage.
7. Auto-activate on `--new` only.
8. Migration token one-burn; no bypass of receipt/shadow-lock/UUID rotation.
9. No service-role or permanent registry creds in installer.
10. No commit/push/deploy without owner authorization.
11. Entitlement resolution must consume provider-neutral commercial grants — never Stripe identifiers as capability truth.
12. Do not cut over high-risk authorization (slots, support tickets, migration burn) until parity is proven and owner authorizes.
