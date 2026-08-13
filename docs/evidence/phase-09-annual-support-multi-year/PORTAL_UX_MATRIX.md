# PORTAL_UX_MATRIX — Phase 9

## Customer-facing surfaces

| Surface | Path / component | Phase 9 behavior |
|---------|------------------|------------------|
| Support landing | `/support`, `support-subscription-landing.tsx` | Annual prepaid primary; monthly hidden/blocked |
| Support tab | Dashboard `support-tab.tsx` | Per-license coverage via coverage API |
| Checkout selector | `support-subscription-selector.tsx` | Year term selection; links to annual checkout |
| Checkout complete | `/checkout/complete` | Existing success flow |

## Coverage display fields

From `GET /api/support/annual/coverage`:

| Field | User-visible meaning |
|-------|---------------------|
| status | active / expired / not_covered / legacy_monthly |
| validUntil | Coverage end date |
| includesTechnicalSupport | Support tier included |
| includesProductUpdates | Updates included (false for monthly legacy) |
| renewalAvailable | Can purchase annual renewal |
| legacyRecurring | On legacy Stripe subscription |
| runtimeNote | ERP keeps running when expired |

## Checkout UX requirements

- Must select **License** before quote/checkout
- Must accept **SLA** (`slaAccepted: true`)
- Multi-year selector (1–max_years from settings)
- Server quote shows discount breakdown before payment
- Stripe redirect for one-time payment (not subscription management portal for prepaid)

## Monthly UX

- Monthly option removed from new-purchase flows
- Error message: `MONTHLY_NEW_SALES_DISABLED_MESSAGE`
- Legacy monthly subscribers see `legacy_monthly` status with note that updates require Annual

## Admin UI

| Route | Component | Functions |
|-------|-----------|-----------|
| `/admin/support-annual` | `support-annual-admin-panel.tsx` | Settings, discount rules CRUD, grant documentation |

Admin grant performed via API (form may POST to `/api/admin/support/annual-grant`).

## RTL note

Soviez RTL design standard applies to any Arabic/RTL chrome for these surfaces — follow `.cursor/skills/soviez-rtl-design/SKILL.md` when implementing localized variants.

## Not in scope

- Installer `--update` UX
- Email receipt template changes (uses existing checkout email pipeline)
- Invoice PDF multi-year line item customization (Stripe product_data name includes term label)
