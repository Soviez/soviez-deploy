# OLD_FLOW_BACKWARD_COMPATIBILITY.md

## Manual Activation

| Check | Result |
|-------|--------|
| Activation key surface on Instance Activation tab | PASS (Playwright Journey D) |
| Manual path remains usable without Device auth | PASS |
| Automatic option additive | PASS (Journey E coexists) |

## Automatic Activation / Devices

| Check | Result |
|-------|--------|
| Device revoke/reauth surfaces present | PASS (Journey E) |
| Exact-License binding | Preserved (Device auth foundation) |
| Failure does not remove manual eligibility | Additive model; manual key retained |

## Migration Token

| Check | Result |
|-------|--------|
| Token count / Migrate Instance action | PASS (Journey F) |
| Self-service flow preserved | PASS |
| No external Odoo import UI introduced as replacement | PASS |

## Existing pages / routes (real shell)

| Surface | Result |
|---------|--------|
| Dashboard / Overview | PASS (Journey A; real-saas tests) |
| Instance cards | PASS (Journey B) |
| Instance tabs | PASS (Journey C) |
| Admin shell | PASS (Journey K) |
| Customer cannot open admin | PASS |
| Fixture capability routes redirect to dashboard | PASS |
| Auth login | PASS |
| Legacy monthly visibility / no new sale | PASS (Journey J + API 403) |

## Unrelated product behavior

No intentional replacement of Purchase History, Add-ons Marketplace, Account, Setup Guide, Installation Requests, or Support Tickets routes in this freeze pass. Sidebar destinations remain on `/dashboard`.
