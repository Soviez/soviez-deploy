# DNS_TRY_AGAIN

`--migration-dns-try-again <challenge-id>` re-observes DNS for the **same** challenge.

Unit asserts:

- Same challenge id retained
- Verified after publish
- Second try-again idempotent
