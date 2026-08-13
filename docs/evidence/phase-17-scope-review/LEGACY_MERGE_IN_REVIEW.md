# Legacy `--merge-in` Review

**Date:** 2026-08-01  
**Primary:** `soviez-sh`  
**Legacy:** `soviez-deploy/soviez.sh`

## Finding

There is **no** `--merge-in`, `merge_in`, or `merge-in` implementation in either repository.

Plan and architecture documents use **`--migrate-in`** as the intended sovereign migration entry (Phases 17–22), not “merge-in.”

## Legacy `soviez-deploy/soviez.sh` migration-adjacent behavior

| Behavior | Approx role | Classification |
|----------|-------------|----------------|
| `--init` | Host bootstrap: packages, Docker, Nginx, Certbot, UFW | Existing legacy; **Missing** in soviez-sh; Phase 17 destination bootstrap must reintroduce safely |
| `generate_migration_secret` / `ensure_migration_secret` | Persist `SOVIEZ_MIGRATION_SECRET` for License Guard HMAC | **Not** Migration Token; name collision with commercial “migration” |
| One-time path renames labeled “migration” | Pre-rebrand filename moves | Obsolete naming |
| Stage MAC fingerprint clone | Stage FP parity with Production | Same-host Stage only |
| Unsigned self-update | Online script overwrite | **Unsafe / obsolete** vs Phase 7 signed releases |

Legacy CLI surface (~`--init` / `--new` / `--update`) has **no** server↔server migrate flag.

## Implication for Phase 17

- Do **not** invent a parallel “merge-in” control plane.
- Prefer product flag family `--migration-*` (see corrected scope CLI proposal) or documented `--migrate-in` umbrella — **owner decision** on exact flag spelling.
- Destination `--init` must be rebuilt in soviez-sh against Phase 7 trust + Phase 14 ops — not copy-paste unsigned legacy self-update.

## Verdict

**Legacy merge-in = never existed.** Phase 17 greenfield for discovery/bootstrap/pairing, reusing Device Auth, Registry, Ops Engine, Backup gates, and SaaS eligibility APIs — not a port of a merge-in command.
