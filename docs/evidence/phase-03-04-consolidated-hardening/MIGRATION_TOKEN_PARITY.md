# Migration Token parity

| Scenario | Result |
|----------|--------|
| Wallet aligned with grant quantity | PASS |
| Consume (wallet + grant exhausted) | PASS |
| Current burn remains authoritative | Confirmed (no cutover) |

Wrong account/license: covered by capability resolver account scoping + existing migrate RPC ownership (unchanged).
