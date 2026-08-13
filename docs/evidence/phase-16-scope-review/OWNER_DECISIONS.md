# OWNER_DECISIONS.md — Phase 16

Owner decisions for Phase 16 Production Backup/Restore.  
**Status:** CLOSED (implemented Phase 16 PASS)  
**Decision log pointer:** D097 + OD-01…OD-18 rows in `docs/ai/DECISION_LOG.md` (supersedes D096 pending state)

---

## OD-01 — Local encryption mandate

**Question:** Is encryption mandatory for local backups, or only for remote backups?

**Review recommendation:** Remote = mandatory. Local = default-on with explicit owner opt-out acknowledgment.

**Owner answer:** Local default ON; remote mandatory; advanced local opt-out via `SOVIEZ_BACKUP_DISABLE_ENCRYPTION=1`.

---

## OD-02 — First remote destinations

**Question:** Which first remote destinations should Phase 16 support?

**Review recommendation:** S3-compatible object storage + SFTP (owner-controlled). Soviez-hosted out of scope.

**Owner answer:** S3-compatible + SFTP (owner-controlled). Soviez-hosted out of scope.

---

## OD-03 — Indefinite pins

**Question:** Should manually pinned Production backups be allowed indefinitely?

**Review recommendation:** Yes, with capacity warnings; pins independent of Stage 14–60.

**Owner answer:** Yes — pins protected from retention automation indefinitely.

---

## OD-04 — Default retention policy

**Question:** What is the default retention policy?

**Review recommendation (discussion only):** keep last 7 successful Full backups or 30 days (whichever retains more); never auto-delete the sole restore-capable backup without confirmation.

**Owner answer:** Classification keep **7 daily / 4 weekly / 12 monthly**; protect latest successful/verified/restore_tested and pins.

---

## OD-05 — Automated restore drills

**Question:** Should automated restore drills be included now?

**Review recommendation:** Implement `backup_restore_test` op now; enable periodic schedule only if owner says yes.

**Owner answer:** Yes — `backup_restore_test` / `--restore-test` included now.

---

## OD-06 — Database-only backup

**Question:** Should database-only backup be allowed?

**Review recommendation:** Advanced-only with hard confirmation and explicit warning — not default. (Not diagnostic-only.)

**Owner answer:** Advanced-only (`--type database-only --advanced`); not a Full Production restore source.

---

## OD-07 — Incremental / WAL

**Question:** Should incremental/WAL backups be included or deferred?

**Review recommendation:** **DEFER** to a later phase. Too complex for Phase 16.

**Owner answer:** DEFERRED — no WAL/PITR in Phase 16.

---

## OD-08 — Cross-host restore

**Question:** Is cross-host restore part of Phase 16 or future migration?

**Review recommendation:** **Out of Phase 16** → Phase 17 / migration + reactivation.

**Owner answer:** Out of Phase 16 — cross-host restore denied (`RESTORE_HOST_IDENTITY_MISMATCH`).

---

## OD-09 — Restore-as-Stage

**Question:** Is restore-as-Stage allowed, and does it require Stage entitlement?

**Review recommendation:** Allowed only with Stage entitlement + Stage License rules; separate from Production restore.

**Owner answer:** Allowed via `--restore-as-stage` under Stage entitlement/domain rules.

---

## OD-10 — Default scheduled backup time

**Question:** What is the default scheduled backup time?

**Review recommendation:** Low-traffic host-local window (e.g. 02:00 local); exact time owner-chosen.

**Owner answer:** **02:00 server-local**.

---

## OD-11 — Maximum backup concurrency per host

**Question:** What maximum backup concurrency should be allowed per host?

**Review recommendation:** Default **1** Production backup at a time; queue others.

**Owner answer:** Conflict-locked via ops engine (Production backup conflict class).

---

## OD-12 — Default bandwidth/CPU limits

**Question:** What default bandwidth/CPU limits should apply?

**Review recommendation:** Conservative CPU nice + configurable remote MB/s cap; defaults owner-set.

**Owner answer:** Default resource profile `balanced` + capacity preflight margins.

---

## OD-13 — Rollback safety window after restore

**Question:** What is the rollback safety window after restore?

**Review recommendation:** Align spirit with Phase 15 (e.g. 24h) unless owner picks different duration.

**Owner answer:** **24h** (`SOVIEZ_RESTORE_SAFETY_WINDOW_HOURS`).

---

## OD-14 — Remote destination configuration scope

**Question:** Should remote backup destinations be globally configured or per Production?

**Review recommendation:** Support both; default per Production for multi-tenant hosts.

**Owner answer:** Destination profiles local; schedules bind destination per Production.

---

## OD-15 — Destination credential management

**Question:** Should backup destination credentials be managed only locally or optionally through encrypted SaaS administration?

**Review recommendation:** **Local only** for Phase 16. No SaaS custody of backup keys/credentials.

**Owner answer:** Local only — no SaaS custody of backup keys/credentials.

---

## OD-16 — Deletion confirmation under retention automation

**Question:** Should backup deletion require interactive confirmation even under retention automation?

**Review recommendation:** Automation may delete per policy without TTY; manual `--backup-delete` always confirms; sole remaining backup always confirms.

**Owner answer:** Retention cleanup / manual delete use confirm gates; pins always protected.

---

## OD-17 — Verification before retention validity

**Question:** Should backup verification be mandatory before retention considers a backup valid?

**Review recommendation:** Yes for integrity verification at minimum before counting as “last successful/valid.”

**Owner answer:** Yes — verification before `latest_verified` / preferred restore source.

---

## OD-18 — Long-term portable formats

**Question:** What backup formats are considered portable and supported long-term?

**Review recommendation:** Versioned Full backup: `pg_dump -Fc` + filestore archive (zstd/gzip) + manifest schema. Freeze format list explicitly on implementation auth.

**Owner answer:** `pg_dump -Fc` + filestore archive + signed `soviez.backup.v1` manifest.

---

## Blocking rule

OD-01…OD-18 answered via implementation PASS (D097). Phase 16 authorized and complete.
