# EXISTING_TRANSFER_CAPABILITY_INVENTORY.md

**Scope:** Inventory of transfer-adjacent capabilities for Phase 19 planning. No runtime changes.  
**Date:** 2026-08-02

## Classification legend

| Class | Meaning |
|-------|---------|
| **Reusable** | Use as-is or with thin adapter |
| **Refactor** | Reuse pattern; extend for durable cross-host transfer |
| **Unsafe** | Must not be primary migrate stream without redesign |
| **Missing** | Required for Phase 19; not present |

---

## Reusable

| Capability | Origin | Notes for Phase 19 |
|------------|--------|--------------------|
| `pg_dump_fc` / `restore_fc` | Phase 16 (+ Stage shared helpers) | Final DB pass; not continuous WAL |
| Filestore tar.zst + checksums/manifests | Phase 16 | Pattern for object integrity; prefer file-level chunked pre-sync for live migrate |
| SFTP/S3 backup destinations | Phase 16 | **Prerequisite/off-box backup only** — not migrate path |
| Stage live backup | Phase 16/11 | Optional Stage payload when explicitly selected |
| Phase 14 ops engine | Phase 14 | Heartbeat, conflict, reboot recovery shell for `migration_transfer_*` |
| Phase 17 mTLS cert issue | Phase 17 | Seed material for transfer plane identity |
| `assert_no_transfer` / token eligibility | Phase 17 | Keep until authorized transfer modules + scoped gate updates |
| Phase 18 routing readiness inputs | Phase 18 | Pair + mig TLS/landing as transfer eligibility inputs |
| Offline trust packages | Phase 17 | Pairing/bootstrap offline; not payload relay |

---

## Refactor

| Capability | Why refactor |
|------------|--------------|
| Phase 17 mTLS (ephemeral / readiness) | Promote into **durable transfer plane** (chunk session, resume registry, mutual auth, no TOFU) |
| Phase 15 update-candidate staging | Analogy for **destination non-Production staging identity** (isolated apply, no switch) |
| Phase 16 restore apply patterns | Cross-host apply allowlist; **without** same-host Production switch |
| Backup manifest / checksum pipeline | Extend to transfer manifest + chunk digests (`TRANSFER_MANIFEST_MODEL.md`) |

---

## Unsafe as primary stream

| Capability | Risk |
|------------|------|
| Phase 16 full archive → SFTP/S3 as migrate path | Giant source archive; wrong trust boundary; not direct peer stream |
| Same-host restore switch | Activates/switches Production on one host — not destination staging |
| Legacy deploy backup tar (`soviez-deploy`) | Untyped, non-ops, non-pair-bound; unsuitable primary |

---

## Missing

| Gap | Needed for |
|-----|------------|
| Peer streaming worker | Source↔dest chunked mTLS transfer |
| Chunk resume registry | Durable progress / digests / resume after kill |
| Ops adapter `migration_transfer_*` | Phase 14 integration |
| Cross-host apply allowlist | Dest staging restore/apply without Production cutover |
| Source write-freeze controller | App write freeze ≠ ERP stop ≠ PG stop ≠ landing |
| Destination staging identity | Isolated non-Production; no slot; no public login |
| CLI transfer commands | Explicit start/status/abort/resume (authorized impl only) |

---

## Static gates note

Current security static gates **BAN** `pg_dump` (and related payload tools) under `src/migration/**`. Phase 19 implementation must introduce **authorized transfer modules** plus **scoped gate updates** that allow dump/restore only on the transfer path while preserving bans on token consume, Production cutover, and SaaS payload proxy. Until then, no `src/migration` transfer code is authorized.
