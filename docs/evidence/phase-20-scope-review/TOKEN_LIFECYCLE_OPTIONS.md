# TOKEN_LIFECYCLE_OPTIONS.md

## Option 1 — Durable reservation

```text
available → reserved → consumed
```

Today’s SaaS `begin_license_migration` approximates this by **debiting wallet at begin** and completing on `migrate_license_ip`.

**Risks:** long-lived holds; cancel/TTL complexity; “reserved but abandoned”; commercial grant not updated; not installer-idempotent.

## Option 2 — Atomic consume-on-commit (recommended)

```text
available → (short-lived transaction lock) → consumed IFF authorization committed
```

- No long-lived commercial reservation state.
- Preconditions validated first.
- Consume exactly once inside the same authoritative transaction that records destination binding + source grace authorization.
- Pre-commit failure → token remains available.
- Post-commit retries → same signed result (idempotency key).
- Forbidden: consumed without binding; binding without consume.

## Option 3 — Keep wallet session + shadow grant

Continue 070 wallet reserve; separately sync grant. **Reject as end-state** (dual truth). May be transitional during cutover with explicit dual-write.

## Recommendation

**Option 2.** Short-lived lock (advisory + row lock / allocation row with TTL minutes, not hours) is allowed as implementation detail, not a customer-visible “reserved credit” lasting beyond the atomic operation window.
