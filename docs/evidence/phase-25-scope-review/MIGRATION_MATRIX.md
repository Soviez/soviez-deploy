# Migration matrix

| Stage | Owner | Phase 25 |
|-------|-------|----------|
| Discovery | 17 | Revalidate |
| Trust pairing + offline packages | 17 | Revalidate |
| Destination bootstrap | 17 | Revalidate |
| Domain/DNS/TLS/landing readiness | 18 | Revalidate |
| Direct streaming + resume | 19 | Revalidate E2E |
| Authorization / token / rebind / activation | 20 | Revalidate E2E |
| Cutover / health / rollback | 21 | Revalidate E2E-08 |
| Rollback window / archive / retirement readiness | 22 | Revalidate; **no purge** |

E2E-07 and E2E-08 mandatory. Purge remains separately authorized.
