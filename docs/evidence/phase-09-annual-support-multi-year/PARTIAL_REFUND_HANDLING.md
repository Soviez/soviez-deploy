# PARTIAL_REFUND_HANDLING — Phase 9

## Policy status: REQUIRES_ADMIN_REVIEW (unresolved business policy)

**Decision D015 preserved:** Phase 9 does **not** implement automatic partial-refund proration or proportional coverage trimming.

## Implemented behavior

When Stripe reports a partial refund on a prepaid Annual Support purchase:

```typescript
if (amountRefunded > 0 && amountRefunded < amountCaptured) {
  await reverseCoverageByIdempotencyKey(
    supabase,
    coverageKey,
    "partial_refund_requires_review",
    { type: "stripe", reason: "partial_refund" }
  );
}
```

### Database effects

| Entity | Change |
|--------|--------|
| `support_coverage_periods.status` | `requires_admin_review` |
| `support_coverage_events` | `partial_refund_requires_review` event |
| `user_addons` | **No change** |
| Commercial grants | Follows existing partial refund ledger behavior (legacy) |

### Customer impact

- Coverage may remain **active** until admin resolves
- Portal may still show active coverage (admin must manually adjust if business decides to trim)
- Denial code reserved: `PARTIAL_REFUND_REQUIRES_REVIEW`

## What is NOT implemented

- Automatic calculation of remaining coverage days from refund ratio
- Automatic period split or truncation
- Customer notification workflow
- Admin UI for partial-refund resolution queue

## Owner decisions still required (D015, D008)

1. Business rule: trim coverage proportionally vs. keep until manual review?
2. SLA for admin resolution turnaround
3. Whether partial refund should immediately deny `product_updates` strict resolver

## Certification

DB harness verifies RPC sets `requires_admin_review` status — **PASS**.

No live Stripe partial refund webhook tested.
