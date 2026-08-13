# Legacy Backup Review — soviez-deploy/soviez.sh

**Reference:** `/Volumes/PortableSSD/soviez-project/soviez-deploy/soviez.sh`  
**Modes:** `--backup <tenant> <db>`, `--backup-list`

## What legacy does well

| Strength | Detail |
|----------|--------|
| Real DB dump | `pg_dump -Fc` (custom format) |
| Filestore archive | tar.gz alongside dump |
| Destination | `/var/soviez/backups` |
| Capacity guard | `BACKUP_SAFETY_MARGIN_BYTES` = 5 GiB host free buffer |
| Inventory | `--backup-list` table of archives |
| Operator UX | Clear wait/error messages |

## What legacy lacks (Phase 16 must address)

| Gap | Impact |
|-----|--------|
| **No restore** | Backup without verified restore path |
| No ops engine | No durable operation id, heartbeat, cancel, reboot recovery |
| No encryption | Archives at rest in clear |
| No remote destination | Local disk only |
| No candidate-first restore | Would imply direct overwrite if restore were added naively |
| No License Guard restore model | Not integrated with slot/candidate identity |
| No verification levels | No restore-test / privacy-preserving aggregates |
| No scheduled Production backup | Manual only |
| No pin/retention policy product | Ad-hoc files on disk |
| Monolith | Not modular; hard to reuse inside soviez-sh |

## Mapping legacy → corrected Phase 16

| Legacy behavior | Phase 16 treatment |
|-----------------|--------------------|
| `pg_dump -Fc` | Keep as default DB component of **full** backup |
| Filestore tar | Keep as component; prefer portable archive + manifest |
| 5GB fixed margin | Replace with **computed** capacity model + documented safety margin |
| `/var/soviez/backups` | Local destination **required**; structured inventory IDs |
| `--backup-list` | Expand to show verify/pin/retention/RPO fields |
| No restore | **Candidate-first** Production restore (Phase 15 pattern) |
| No encryption | Remote mandatory; local default-on with owner opt-out (**OD**) |

## Do not

- Copy legacy restore-from-web or invent direct overwrite restore.  
- Treat legacy as already satisfying Phase 16 acceptance.  
- Dual-ship legacy `--backup` and modular `--backup` without clear deprecation later.

## Verdict

Legacy proves customer demand for Production DB+filestore archives and a useful space check.  
Phase 16 must **reimplement** as a restore-capable, ops-integrated, encrypted-capable product — not extract-and-hope from the monolith.
