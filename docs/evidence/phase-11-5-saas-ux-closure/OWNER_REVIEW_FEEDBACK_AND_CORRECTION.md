# Owner review feedback and design correction — Phase 11.5

## What was wrong in the first owner review

The first Phase 11.5 preview introduced a **parallel product shell**:

- Horizontal top navigation (`ProductShellNav`) replacing the existing vertical sidebar TabsList
- Separate top-level pages for Licenses / Servers / Stages / Operations / Billing
- A different page composition and IA than the live Client Dashboard

Owner feedback (binding): extend the **existing** sidebar-based SaaS UI; do not change the overall shape of the product.

## What was reverted / corrected

| Item | Action |
|------|--------|
| `ProductShellNav` customer/admin chrome | Removed from live shells; stubbed no-op |
| Standalone `/dashboard/servers`, `/stages`, `/operations`, `/licenses`, `/billing`, `/devices` | Redirect into `/dashboard` (or purchase-history tab) |
| Preview customer UI | Rebuilt as **same** vertical sidebar shell as `DashboardShell` |
| License-centered detail | Compact instance cards on Overview; expand into in-card tabs |

## Pages removed / merged / restructured

**Merged into Overview → Instance detail tabs:**

- Server / Connection
- Annual Support (incl. legacy monthly + pricing policy copy)
- Stage License
- Stages
- Operations (+ offline request export)
- Security

**Kept as existing dashboard sidebar sections:** Overview, Support Tickets, Marketplace, Purchase History, Account.

**Admin:** satellite capability pages keep `InternalPageHeader` + content panel (existing admin pattern); no top-nav admin shell.

## Annual Support pricing policy (English UI)

- Reference = 20% of current localized official License **list** price
- Not derived from discounted net purchase
- Multi-year discounts on support package: 1y 0%, 2y 10%, 3y 15%, 4y 20%, 5y 25%
- Renewals from then-current official list price; early renewal extends after current end

## Preview after correction

- URL: `http://127.0.0.1:3011/login?preview=1`
- Customer: `customer.demo@soviez.preview` / `Preview-Customer-11.5!`
- Admin: `admin.demo@soviez.preview` / `Preview-Admin-11.5!`

## Status

`OWNER REVIEW READY — PHASE 11.5 DESIGN CORRECTION APPLIED`

First preview was **not** approved. Final PASS / 65% still requires owner approval of this corrected preview. Phase 12 unauthorized.
