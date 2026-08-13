# SIGNING_AND_KEY_SEPARATION — Phase 10.5

| Domain | Used for | Shared with Stage ops? |
|--------|----------|------------------------|
| `soviez.device-auth.v1` | Device Auth | **No** |
| License / activation | ERP license | **No** |
| `soviez.release-manifest.v1` | Release catalog | **No** |
| `soviez.registry-pull-ticket.v1` | Image pull | **No** |
| Migration HMAC | Migration receipts | **No** |
| Stripe webhook | Payments | **No** |
| `soviez.stage-operation.v1` | Stage Operation Tickets | **Yes — only this** |

Env separation: `SOVIEZ_STAGE_OPERATION_PRIVATE_KEY`, `SOVIEZ_STAGE_OPERATION_PUBLIC_KEYS_JSON`, `SOVIEZ_STAGE_OPERATION_KEY_ID`.

Helper ships public keys only. Private key never in `signed_package` tooling.

**Tests:** _(parent fills)_
