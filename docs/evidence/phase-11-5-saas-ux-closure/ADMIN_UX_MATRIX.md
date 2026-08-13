# ADMIN_UX_MATRIX.md

| Capability | Surface | Round 3 |
|------------|---------|---------|
| Admin shell | `/admin` | PASS (admin credentials) |
| Customer blocked | `/admin` as customer | PASS (redirect / not admin) |
| Annual Support settings | Admin commercial (schema + seed) | Present in demo DB `support_commercial_settings` |
| Stage License settings | `stage_license_settings` | Enabled in demo |
| Devices / grants / transactions | Provider-neutral tables | Populated by Stripe fulfill + seed |
| Role boundaries | Admin vs customer | PASS |
