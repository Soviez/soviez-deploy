# PRODUCT_AND_PRICING — Phase 10

- Internal code: `stage-license-monthly`
- Capability: `stage_environments` (exact license)
- Billing: recurring monthly (`mode: subscription`)
- Price: server-side via `addons` / country pricing; quote expiry 15m
- Browser amounts ignored; snapshot immutable on purchase
- Fixture default seed price `4900` cents USD when addon catalog present (not production authority)
- Product disable → `STAGE_LICENSE_DISABLED`
- Missing price → `PRICE_NOT_CONFIGURED`
