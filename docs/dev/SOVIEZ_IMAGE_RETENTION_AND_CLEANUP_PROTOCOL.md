# Soviez Image Retention and Cleanup Protocol

**Phase:** 15 final certification  
**Modules:** `src/update/images/`  
**Operation type:** `update_image_cleanup`

## Policy

1. Retain **current** and **rollback** digests for each Production.
2. Default post-switch safety window: **24 hours**.
3. Never run broad prune (`docker system prune`, `image prune -a`).
4. Delete only digests classified `eligible_for_cleanup` after ownership + reference + TOCTOU checks.
5. Report shared-layer accounting honestly (reclaim ≤ logical sum).

## Pipeline

```text
forbid_prune_static_gate
  → resolve current/rollback
  → collect references
  → classify
  → dry_run (optional)
  → execute exact deletes with per-image TOCTOU revalidation
  → history under $SOVIEZ_UPDATE_ROOT/image_cleanup/
```

## Ownership labels (managed ERP)

`com.soviez.managed`, `com.soviez.product=erp`, `com.soviez.release-id` (+ digest label when present). Ambiguous → do not delete.

## Reference sources

Running/stopped containers, Production inventory, Stage inventory, candidates, rollback manifests, active ops, recovery sets.

## Conflicts (Phase 14)

| Incoming | Existing | Same env | Decision |
|----------|----------|----------|----------|
| `production_update` | scheduled/waiting `update_image_cleanup` | yes | **`supersede_cleanup`** (cancel cleanup) |
| `update_image_cleanup` | active `production_update` | yes | **deny** |
| `update_image_cleanup` | actively deleting cleanup | yes | **deny** |

## CLI

```bash
sudo soviez.sh --update-image-cleanup <production-id> [--dry-run] [--confirm]
```

Scheduler tick may run due cleanups when window elapsed and no conflicting Production update.
