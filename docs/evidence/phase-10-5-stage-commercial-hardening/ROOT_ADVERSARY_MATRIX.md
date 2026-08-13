# ROOT_ADVERSARY_MATRIX — Phase 10.5

| Scenario | Mitigated? | Residual |
|----------|------------|----------|
| Unentitled authorize | Yes — entitlement gate | — |
| Stolen device PoP without bindings | Partial — bindings required | Compromised device on correct host |
| Ticket replay online | Yes — consume one-use | — |
| Expired ticket START | Yes — `TICKET_EXPIRED` | Does not stop running Stage (by design) |
| Offline package reuse | Partial — local ledger | Root rewrites ledger |
| Replace helper binary | No (crypto) | Full Root bypass — accepted |
| Steal Stage Operation private key | Ops controls | Catastrophic if leaked |
| Redistribute tooling | Attribution via `delivery_trace_id` | Does not remotely disable |
| Kill Stage via license expiry | Forbidden by design | N/A — must not happen |

**Tests:** _(parent fills)_
