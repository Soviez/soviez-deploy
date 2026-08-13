# PLAYWRIGHT_BROWSER_MATRIX.md — Round 4

## Install

- Package: `@playwright/test@1.54.2` (project-local)
- Browsers path: `PLAYWRIGHT_BROWSERS_PATH=/tmp/soviez-playwright-browsers`
- Config: `soviez-saas/playwright.config.ts`
- Spec: `soviez-saas/e2e/phase115.journeys.spec.ts`

## Chromium desktop (required journeys) — Round 4 re-run

| Journey | Result |
|---------|--------|
| A Dashboard preservation | PASS |
| B Instance cards three-status | PASS |
| C Instance detail tabs | PASS |
| D Manual activation | PASS |
| E Automatic activation surface | PASS |
| F Migration tokens | PASS |
| G Annual Support quote + Stripe open (EGP 54,000 / 2y; no UUID error) | PASS |
| G2 Annual Support Stripe pay + complete | PASS |
| I Stage License Stripe open | PASS |
| J Legacy monthly | PASS |
| K Admin shell | PASS |
| customer cannot open admin | PASS |

**Latest full desktop run: 12/12 passed.**

## Chromium mobile viewport — Round 4

| Journey | Result |
|---------|--------|
| A | PASS |
| B | PASS |
| G (quote/CTA; Stripe soft-assert on mobile) | PASS |

**Latest mobile A/B/G: 3/3 passed.**

## Error gates

Suite fails on `pageerror`, console errors containing `randomUUID`, and unhandled rejections related to checkout.

## Firefox / WebKit

Not run in this pass. Recorded honestly as not executed.

## Owner browse URL

Use **http://127.0.0.1:3011** or **http://localhost:3011** — never advertise `0.0.0.0` as the browser URL.
