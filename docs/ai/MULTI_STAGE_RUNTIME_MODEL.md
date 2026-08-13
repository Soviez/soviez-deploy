# Multi-Stage Runtime Model (Phase 11)

**Status:** Implemented — **PASS** (2026-07-30)  
**Repo:** `soviez-sh`  
**Version:** `0.13.0-phase13` (Phase 11 runtime plus Phase 13 retention)  
**Evidence:** `docs/evidence/phase-11-multi-stage-runtime/`  
**Protocols:** `docs/dev/STAGE_RUNTIME_PROTOCOL.md`, `docs/dev/STAGE_NEUTRALIZATION_PROFILE.md`  
**User guide:** `docs/user/STAGE_ENVIRONMENTS.md`

---

## 1. Objectives

1. Allow **multiple Stage environments** per exact Production License / tenant, each with unique identity, database, container, MAC, Docker network, domain, SSL, filestore, config, and secrets.
2. Clone Production into Stages via **safe snapshot** (`pg_dump` / restore) and **filestore copy** — never mutate Production, never share writable storage.
3. Wire Phase 10 entitlement + Phase 10.5 Stage Operation Tickets + Node helper into installer `--stage` so enforcement is **not Bash-only**.
4. Enforce **local resource admission** while keeping commercial Stage count **unlimited**.
5. Require **trusted-chain SSL** (self-signed rejected as final PASS).
6. Certify **neutralization** via helper before Stage-origin certificate issuance.
7. Preserve sovereignty: expiry never stops existing Stages; no Core License Slot consumption; no periodic phone-home; honest Full-Root residual (not DRM).

---

## 2. Non-goals (this phase)

| Excluded | Notes |
|----------|-------|
| Retention implementation details | Delivered in Phase 13; see §17 |
| `--update` | Later phase |
| Stage refresh / rebuild / clone-from-Stage as product ops | Not productized this phase |
| Production migration / source retirement | Later phases |
| Automatic DNS-provider mutation | Out of scope |
| Live SaaS / Stripe / Hub deploy | Forbidden |
| Unbreakable DRM | Forbidden claim |
| Changing `local_license_guard` | Untouched |

---

## 3. Production → Stage

A Stage is a **neutralized, isolated clone** of one managed Production:

1. Select healthy managed Production (exact `license_id`, fingerprint, `database.uuid`).
2. Reserve unique Stage identity in `/var/soviez/stages`.
3. Admit local resources.
4. Authorize Device + Stage License entitlement + Stage Operation Ticket (connected or offline package).
5. Snapshot Production DB with **`pg_dump -Fc`** (never copy live PostgreSQL data directory).
6. Snapshot filestore by **copy/rsync** into operation snapshot (never symlink / shared mount).
7. Restore into Stage-owned DB name `stage_<id>` and Stage filestore path.
8. Create Stage runtime on dedicated Docker network `soviez-net-stage-<id>`.
9. Apply neutralization controls; **helper certifies**.
10. Issue domain + trusted SSL; validate chain.
11. Issue Stage-origin certificate; optionally report remote completion.
12. Mark lifecycle `certified` / `running`.

Stage is **not** a new Production License and does **not** consume a Core License Slot.

---

## 4. Unlimited commercial / resource-limited

| Layer | Rule |
|-------|------|
| Commercial (Phase 10) | No per-license Stage count cap while entitlement is active |
| Local admission (Phase 11) | Disk, inode, memory, load, and inventory checks may **block** or **warn** |
| Formula | `projected ≈ (db+filestore)×2.5 + 2 GiB`; block if available < projected or MemAvailable < 1 GiB |

Denial codes: `RESOURCE_ADMISSION_FAILED`, `INSUFFICIENT_DISK`, `INSUFFICIENT_MEMORY`.

---

## 5. License binding

Every Stage binds:

- Exact `license_id` (Stage License entitlement)
- Parent Production `tenant_id`
- `production_fingerprint`
- Source `database_uuid` (Production)
- Stage `stage_id`, `stage_domain`
- Release + tooling digests (ticket bindings)

Cross-Production binding fails closed (`TICKET_BINDING_MISMATCH` / fingerprint mismatch).

---

## 6. Connected and offline flows

### Connected

```
soviez.sh --stage --stage-id <id> --stage-domain <fqdn>
  → device (silent if credential present)
  → entitlement check
  → authorize ticket (SaaS)
  → helper verify + consume
  → snapshot / restore / runtime / neutralize / SSL / origin cert
  → complete (remote when online)
```

### Offline

1. Export request: `soviez.stage-offline-request.v1` (no business data) via `--stage --offline-request`.
2. Obtain signed offline package + tooling on a connected device (`soviez.stage-offline-auth.v1`).
3. Import on the target with `--stage --offline-import <package>` — verify bindings, consume local ledger, create Stage with no SaaS.
3. Import package locally; helper verifies + records one-use ledger consumption.
4. Continue snapshot/runtime/neutralization/SSL/origin cert without further SaaS.

---

## 7. Snapshot (pg_dump — not live PG directory)

- Source: managed Production database via `pg_dump -Fc` (Docker exec or host).
- Artifacts under `/var/soviez/ops/stage/<op_id>/snapshots/` (`db.dump`, checksums).
- Restore: `createdb` + `pg_restore` into Stage DB only.
- **Forbidden:** copying `$PGDATA`, stopping Production for cold copy, mutating Production rows during clone.

Certification used `SOVIEZ_TEST_MODE` fixtures with **real file copy + dump files** (not empty mocks). Production docker/`pg_dump` paths exist in source for live hosts.

---

## 8. Filestore clone (no shared writable)

- Snapshot copies Production filestore into op snapshot, then into `/var/soviez/stages/<id>/filestore`.
- Destination must not be a symlink to Production; external absolute symlinks rejected.
- Production filestore checksum must remain unchanged after Stage create (proven in integration A/B/C).

---

## 9. Runtime isolation

| Resource | Naming |
|----------|--------|
| Stage ID | `[a-z0-9][a-z0-9_-]{1,62}` |
| DB | `stage_<id>` (`-` → `_`) |
| Container | `soviez-stage-<id>` |
| Network | **`soviez-net-stage-<id>`** (dedicated per Stage — D060) |
| MAC | Locally administered unicast `02:…` (not Production MAC) |
| Labels | `soviez.role=stage`, `soviez.stage_id=…` |

Legacy shared `soviez-net-stage` is **not** used for new Stages.

---

## 10. Licensing (no Core Slot)

Stage creation consumes Stage License entitlement + operation ticket capacity semantics — **never** a Core License Slot. Slot reservation remains Production `--new` only.

---

## 11. Domain / SSL

- Mandatory unique Stage domain/subdomain.
- DNS validation required (fixture mode for tests).
- Certificate must validate against a **trusted CA** chain.
- **Self-signed leaf without trusted CA is rejected** as final PASS (`SSL_ISSUANCE_FAILED`).
- Production path prefers Let's Encrypt when issuer helpers are present.

---

## 12. Neutralization via helper

Bash/ERP apply controls; **`soviez-stage-helper neutralize`** certifies. Bash Boolean alone cannot certify a Stage. See `STAGE_NEUTRALIZATION_PROFILE.md`.

Must-disable / isolate: outgoing email, SMS, payment providers, webhooks, external cron, production URL callbacks; set stage identity marker + neutralized flag.

---

## 13. Origin certificate

Type `soviez.stage-origin-certificate.v1` written under Stage inventory. Local evidence only — no phone-home. Survives Stage License expiry. Retention fields remain placeholders until Phase 13.

---

## 14. Lifecycle

| Command | Entitlement required? |
|---------|----------------------|
| `--stage` (create) | Yes (+ ticket) |
| `--stage-list/status/start/stop/backup/drop` | No |

Drop requires explicit Stage ID confirmation (`SOVIEZ_STAGE_DROP_CONFIRM` for non-TTY). Removes only Stage-owned container/network/inventory — never Production.

---

## 15. Expiry guarantees

| Event | Effect |
|-------|--------|
| Stage License expired / past_due / revoked | Deny create/clone/refresh/rebuild |
| Ticket `exp` | Deny **START** of gated op only |
| Either expiry | Existing Stages remain listable, startable, stoppable, backupable, safely droppable |
| Either expiry | Does **not** stop or delete existing Stages |

---

## 16. Cleanup boundaries

- Drop/remove affects only selected Stage resources and that Stage's dedicated network.
- Operation failure cleanup is limited to operation-owned snapshots/temp paths.
- **No** global `docker system prune`, **no** Production teardown, **no** automatic retention purge in Phase 11.

---

## 17. Stage retention (Phase 13 PASS)

Each Stage has local `retention.json`: default lifetime is 14 calendar days from immutable original `created_at`; the absolute ceiling is 60 calendar days from that same timestamp. Extension `--days` means total lifetime and cannot reset or shorten the clock.

The local scheduler renders an English daily countdown/banner and records warnings. At expiry it verifies a final backup, runs Safe Shield, deletes only exact Stage-owned resources, and writes a tombstone. Failed backup, ambiguous ownership, collision, or partial deletion fails closed to Needs Action/recovery-required and supports retry/reattach. No retention action consults entitlement or phones home.

---

## 18. Honest residual (not DRM)

Full Root can replace the helper binary, rewrite the offline ledger, or rebuild orchestration. Signatures prevent forgery; they do not prevent verifier replacement. Soviez does **not** claim unbreakable DRM.

---

## 19. Progress

Phase 11 weight **8**. Cumulative after Phase 11: `52 + 8 = 60%`.  
Phase 12 (Domain/SSL lifecycle) weight **4** PASS → **64%** (`60 + 4`).  
Phase 13 (Stage retention) weight **3** PASS → **67%** (`64 + 3`). Phase 14 remains unauthorized.
