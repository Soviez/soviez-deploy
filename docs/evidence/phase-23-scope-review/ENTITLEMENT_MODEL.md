# ENTITLEMENT_MODEL

| Capability | Role |
|------------|------|
| product_updates | Authorizes entitled product updates (exact License) |
| offline_update_bundle | Authorizes issuance of offline delivery artifact |
| private_image_pull | Connected export worker only — not on air-gapped server |
| technical_support | Support; monthly never grants updates |

Recommended: both product_updates + offline_update_bundle at issuance; exact License; deny refunded/disputed/revoked; provider-neutral; **no consumable quantity**; immutable issuance record; exact License/device/version binding; post-issuance entitlement expiry does not void unexpired bundle unless revoked before use (honest offline limit).
