# E2E fixture matrix

Harness: Docker Postgres 16, dynamic `127.0.0.1` port, migrations 078–080, pg-admin dual-write adapter.

| Fixture | Result |
|---------|--------|
| Stripe license dual-write + duplicate | PASS |
| Monthly/annual/unbound/legacy support + product_updates | PASS |
| Admin license grant (admin_grant, no Stripe ref) | PASS |
| Admin annual addon + cross-license denial | PASS |
| Refund + dispute + reinstate idempotent | PASS |
| Subscription past_due/expired | PASS |
| Migration token wallet↔grant parity | PASS |
| Slot consumption sync parity | PASS |
| Pending/failed no active grants | PASS |
| Backfill/materialize idempotency + RLS | PASS |
| Complimentary grant issue/revoke | PASS |
| Portal select-shape compat | PASS |
