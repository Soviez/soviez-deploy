# Migration Authorization Recovery

## When to use this guide

- Commit command hung or returned an unknown error.
- You are unsure whether the Migration Token was consumed.
- Activation failed after a successful commit.
- You need to retrieve an authorization receipt.

## Safe recovery principles

1. **Never retry commit with a new idempotency key** if the first commit may have succeeded — that could attempt a second consume.
2. **Always recover with the same idempotency key** used in the original commit attempt.
3. Phase 20 does **not** automatically refund tokens on failed local activation.

## Recover authorization receipt

By operation id:

```bash
./soviez.sh migration authorization recover --operation-id <op-id>
```

If you have the idempotency key, set `SOVIEZ_MIG_P20_IDEMPOTENCY_KEY` to the original value before recover.

## Interpret results

| Outcome | Meaning | Next step |
|---------|---------|-----------|
| Receipt returned | Commit succeeded | Proceed to activation with `authorization_id` |
| `MIGRATION_AUTHORIZATION_REQUIRED` | No commit found | Safe to retry commit with same prerequisites |
| `MIGRATION_TOKEN_IDEMPOTENCY_CONFLICT` | Same key, different payload | Fix payload; do not force retry |
| `MIGRATION_AUTHORIZATION_COMMIT_UNKNOWN` | Transient failure | Recover first, then decide |

## Activation failure after commit

If commit succeeded but destination activation failed:

1. Confirm receipt exists (recover if needed).
2. Fix the reported issue (grace apply, license guard, health, mandatory stage).
3. Re-run destination activate with the same `authorization_id`.

Local apply is idempotent for binding and grace files.

## Token already consumed

If receipt shows `token_quantity_after = 0` (or grant exhausted):

- Token will **not** be automatically restored.
- Pre-cutover reversal requires admin intervention (exceptional; not self-service).
- Contact support with `authorization_id`, `operation_id`, and idempotency key.

## Offline packages

If using offline authorization export/import:

- Each package is single-use; replay is denied.
- Packages expire (typically within 1 hour).
- Reconnect to SaaS for reconciliation when possible.

## What not to do

- Do not set legacy consume flags or bypass canonical commit.
- Do not change DNS to force cutover.
- Do not start a second migration on the same license while grace is active.
