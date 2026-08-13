# PHASE_12_SCOPE_CORRECTION.md

**Date:** 2026-07-30  
**Authority:** Owner-authorized documentation correction only  
**Implementation status:** **AUTHORIZED and PASS** (2026-07-30) — see `docs/evidence/phase-12-domain-ssl-lifecycle/FINAL_REPORT.md`

---

## Reason for correction

The Master Implementation Plan previously titled Phase 12 as **Mandatory Stage domain/SSL** with acceptance “Stage incomplete without SSL validation pass.” That wording **materially overlaps** Phase 11 Secure Multi-Stage Runtime, which already **PASS**-certified:

- Mandatory unique Stage domain  
- Trusted SSL requirement; self-signed rejection for final PASS  
- DNS validation  
- Try Again / Abort foundations in operation state  
- Nginx Stage route stub / validation path  
- Domain collision prevention  
- Trusted local CA certification in isolated tests  
- Stage incomplete without valid HTTPS (state machine `domain_pending` → `ssl_pending`)  
- Connected and offline Stage creation  
- Stage-origin certificate  
- Multi-Stage coexistence with isolated domains  
- Lifecycle and recovery foundations  

Re-implementing initial provisioning under Phase 12 would duplicate Phase 11 and risk regression.

---

## Phase 11 overlap analysis

| Prior Phase 12 wording | Phase 11 ownership (source of truth) |
|------------------------|--------------------------------------|
| Signed challenge / DNS | `DOMAIN_SSL_MATRIX.md`, `MULTI_STAGE_RUNTIME_MODEL.md` §11 |
| Try Again / Abort | Operation state machine + disconnect/resume evidence |
| Valid cert gate for acceptance | Trusted CA chain; `SSL_ISSUANCE_FAILED` for self-signed |
| Remove Stage `force` acceptance (SSL) | Self-signed already rejected as final PASS |
| Stage incomplete without SSL | State machine gates before `completed` |

**Gap remaining for Phase 12:** long-running **lifecycle** after initial issuance (expiry, renewal, rotation, rollback), durable challenge retry/health, Nginx ownership/recovery hardening, Production policy — **not** first-time Stage domain/SSL provisioning.

---

## Corrected title

**Phase 12 — Domain/SSL Lifecycle Hardening, Renewal, Recovery, and Production Policy**

---

## Corrected objective

Focus on **post-provision** operational lifecycle and hardening:

- Certificate lifecycle after initial issuance  
- Expiry detection, renewal, rotation, recovery after renewal failure  
- DNS challenge retry and bounded waiting; durable Try Again / Abort state  
- Nginx configuration ownership, safe reload, rollback after invalid config, conflict detection  
- Certificate-chain validation; IPv4/IPv6 consistency  
- Removal of any remaining unsafe `force` acceptance path not already eliminated  
- Production domain/SSL policy alignment (**owner decisions required** — not decided here)  
- Local-first status and repair; no-downtime or minimal-impact reload  

---

## Corrected scope (summary)

### Certificate lifecycle
Expiry monitoring; configurable renewal window; renewal attempt/retry/backoff; certificate replacement; old-cert rollback; chain/hostname verification; private-key permission validation; certificate metadata inventory.

### DNS challenge lifecycle
Signed challenge verification; finite DNS propagation waiting; Try Again; Abort Safely; resume after interruption; stale challenge detection; exact-domain/host binding; replay protection; **no** automatic DNS-provider mutation.

### Nginx ownership and recovery
Owned generated config; no overwrite of unrelated host config; `nginx -t` before reload; atomic promotion where possible; rollback on failed validation; safe reload; no global restart unless required and documented; collision detection; orphaned config reconciliation; Stage- and Production-specific ownership.

### Repair and diagnostics
Local status (certificate/DNS/Nginx/expiry/renewal); repair command; reattach/recovery where operation engine supports it; no mandatory SaaS for local health checks.

### Production policy
Document and implement **only after** owner answers in `OWNER_DECISIONS_REQUIRED.md`. Do not silently decide.

Full detail: `docs/evidence/phase-12-scope-correction/CORRECTED_SCOPE.md`.

---

## Explicit non-goals

Phase 12 must **not**:

- Reimplement initial Stage domain collection or uniqueness  
- Reimplement initial trusted TLS issuance or self-signed rejection already certified  
- Reimplement Phase 11 Stage creation  
- Redesign Stage entitlement, Stage Operation Tickets, neutralization, or Stage-origin certificates  
- Implement Stage retention (Phase 13), `--update`, backup/restore redesign, or migration  
- Automatically mutate DNS provider records  
- Live-deploy or change SaaS commercial behavior  

---

## Phase 11 vs Phase 12 ownership

| Area | Phase 11 owns | Phase 12 owns |
|------|---------------|---------------|
| Stage domain collection | Initial | — |
| Domain uniqueness | Initial collision deny | Ongoing collision/orphan reconciliation |
| DNS validation | Initial gate | Challenge lifecycle, retry/Abort, stale/replay |
| Trusted SSL issuance | Initial gate | Renewal, rotation, expiry monitoring |
| Self-signed rejection | Final PASS reject | Preserve; remove residual unsafe bypasses |
| Stage creation / runtime isolation | Full | No redesign |
| Stage-origin certificate | Initial issuance | No redesign |
| Nginx Stage route | Initial creation | Ownership, `nginx -t`, safe reload, rollback |
| Production domain/SSL policy | Not closed | Define/implement after owner decisions |
| SaaS commercial / entitlement | Out of scope | Out of scope |

---

## Future acceptance gates

Implementation may PASS only when proven (isolated disposable evidence), including:

- Renewal before expiry; renewal after transient failure  
- Rollback after invalid replacement; old cert available until safe promotion  
- DNS retry and Abort Safely; signed challenge binding; replay rejection  
- Nginx collision detection; unrelated hosts untouched; `nginx -t`; safe reload  
- Reboot/restart recovery; chain verification; hostname mismatch reject; expired cert detection  
- Local health/status without SaaS  
- No self-signed final acceptance; no unsafe `force` path  
- Production policy exactly as separately approved  
- No Phase 11 regression; no live system changes during certification  

---

## Unresolved owner decisions

Listed in `docs/evidence/phase-12-scope-correction/OWNER_DECISIONS_REQUIRED.md` (10 questions). **Not answered** in this task.

---

## Progress handling

- Current progress: **60%**  
- Phase 11.5 visual acceptance: **deferred** (uncredited)  
- Phase 12: **SCOPE CORRECTED — IMPLEMENTATION NOT AUTHORIZED**  
- Proposed weight: **4** (Medium-High, consistent with peer Medium-High phases such as 10.5) — **not applied**  
- No Phase 12 credit  

---

## Implementation authorization status

**NOT AUTHORIZED.**  

Next action: `WAIT FOR OWNER APPROVAL OF PHASE 12 IMPLEMENTATION SCOPE`
