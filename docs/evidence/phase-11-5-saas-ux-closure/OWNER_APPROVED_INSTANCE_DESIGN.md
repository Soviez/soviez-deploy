# OWNER_APPROVED_INSTANCE_DESIGN.md

Owner approved the professional Instance Details visual structure (Round 4).

Implemented in the **real** SaaS app (`InstanceDetailPageClient`), preserving the existing dashboard header and left sidebar.

## Implemented structure

- Header: Back to Overview, friendly name + pencil, License status badge, abbreviated ID, product/version, optional Stripe test mode pill
- Internal tabs (polished horizontal list): Overview, Activation, Migration, Server Connection, Support & Updates, Stage License, Stages, Operations
- Support & Updates: four summary cards (Status, Valid until, Coverage, Product updates)
- Single commercial explanation paragraph (20% of localized list price)
- **Extend / Renew Annual Support** card with aligned pricing rows + prominent Total
- **Included with Annual Support** benefits panel
- CTA label: **Add to Basket** (not “Stripe test checkout”)
- Loading: **Adding…** with duplicate-click protection

Screenshots: `soviez-saas/test-results/phase115-screenshots/support-approved-design.png`
