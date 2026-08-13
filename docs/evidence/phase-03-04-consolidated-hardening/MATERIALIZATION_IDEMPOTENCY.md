# Materialization contract

Migration `080_materialize_capability_result_contract.sql` replaces INTEGER return with JSONB:

```json
{ "examined": N, "inserted": N, "updated": N, "unchanged": N, "skipped": N }
```

| Run | Expectation | Proven |
|-----|-------------|--------|
| First materialize after annual+license | inserted ≥ 1 (or already present from sync) | PASS |
| Immediate rerun | inserted = 0; unchanged/updated ≥ 1 | PASS |
| Status change on parent | updated increments | design + SQL branch |
| Reversal | parent revoked → mapped revoked on rematerialize | PASS via refund/dispute paths |

TS: `materializeMappedCapabilityGrants` returns `{ ok, result }`.
