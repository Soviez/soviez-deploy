# LIVE_UI_BASELINE_PRESERVATION.md

## Baseline preserved

The live customer dashboard implementation remains the product chrome:

- Header: BrandHeaderLink + “Client Dashboard” + utility links + notification bell
- Left vertical sidebar tabs (not a new top navigation)
- `max-w-6xl` content width and existing zinc/indigo card language
- Existing tab destinations: Overview, Setup, Installation Requests, Support Tickets, Marketplace, Purchase History, Purchase Another License, Account (+ partner/post-project when gated)

## Instance detail chrome

`/dashboard/instances/[id]` uses `CustomerDashboardShell`, which mirrors the same sidebar link set and header pattern so Instance workflows stay inside the real product shell.

## Unrelated pages

No redesign of Setup Guide, Installation Requests, Support Tickets, Marketplace layout, Purchase History, Purchase Another License, or Account beyond marketplace monthly-support sale filtering already present.
