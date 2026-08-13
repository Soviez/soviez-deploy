# Portal compatibility matrix

| Surface | Proof | Result |
|---------|-------|--------|
| Customer purchases API fields | Assert select list has no `commercial_*` / unrestricted metadata | PASS |
| Support status record | Assert stable fields; no settlement_status leak | PASS |
| Build/import | `next build` PASS | PASS |
| Auth cutover | None — portal still uses legacy loaders | PASS |

No Playwright suite in repo; route/service field contracts exercised.
