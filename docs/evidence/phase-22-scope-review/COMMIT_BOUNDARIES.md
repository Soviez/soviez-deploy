# Commit Boundaries

## 1. Rollback-window closure commit

After:

- Automatic rollback disabled
- Destination remains traffic owner
- Source no longer immediate rollback origin
- Manual recovery still possible
- **No data deletion**

Requires: stabilization PASS · owner confirmation · source retained · backups valid · no active incident

## 2. Source archive commit

After:

- Archive manifest signed + verified
- Source License finalized
- Source may be suspended
- **No purge**
- Archive immutable per policy

**Service stop ≠ archive success.**  
Archive success requires verified data + manifest evidence.
