# REFUND_DISPUTE_REVOCATION — Phase 10

- Full refund: commercial reverse + Stage entitlement `refunded` + user_addons expired
- Partial refund: `requires_admin_review` — no silent validity shorten
- Dispute: commercial disputed (existing pipeline); Stage mark via refund/dispute hooks where applicable
- Admin revoke: `stage_license_mark_status` → `revoked` with actor/reason
- No existing Stage shutdown signal emitted
