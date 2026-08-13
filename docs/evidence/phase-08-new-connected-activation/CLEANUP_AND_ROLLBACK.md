# CLEANUP_AND_ROLLBACK — Phase 8

## Temp resource cleanup

| Resource | Created by | Cleanup | Certified |
|----------|-----------|---------|-----------|
| Docker config dir | `pull_client.sh` | Deleted after pull | **PASS** |
| ORM staging file | `activate_orm.sh` | Overwrite + unlink in container | Code review |
| Mock server | `integration_env.sh` | `stop_mock` trap | All integration tests |
| Test SOVIEZ_ROOT | Test harness | Temp dir (OS reclaim) | — |

## Cleanup boundaries test

`tests/integration/test_cleanup_boundaries.sh`:

```bash
leftover="$(find "$TMPDIR" /tmp -maxdepth 1 -name 'soviez-docker-config.*' | wc -l)"
assert_eq "0" "$leftover"
```

**Result:** PASS — no global docker prune; no leftover temp configs.

## Operation rollback

| Scenario | Rollback action |
|----------|-----------------|
| Failed before `slot_reserved` | No slot consumed |
| Failed after reserve, before key_issued | SaaS TTL releases hold (Phase 6) |
| Failed after key_issued | Soft-committed; existing Phase 6 reversal policy |
| Manual path complete | Slot at `completed_activation_pending`; user may activate or release via portal |
| Canceled operation | State `canceled`; slot release API available |

## No destructive global cleanup

Installer does **not** invoke:
- `docker system prune`
- Global volume deletion
- Unrelated container stop

Sentinel: stub marker `stubs/container-<op_id>.started` proves container step ran without prune.

## Partial install artifacts

On failure, operation directory retained under `ops/operations/<id>/` for diagnosis and `--reattach`.

Tenant secrets at 0600 retained for resume.

## Full uninstall

Not in Phase 8 scope — deferred to future ops/maintenance phase.
