# OWNER_DECISIONS.md

Status: **PENDING OWNER APPROVAL** — recommendations only; not silently decided for irreversible/commercial policy.

| ID | Decision | Recommendation |
|----|----------|----------------|
| OD-01 | Token reservation exists? | **No** long-lived reservation; short lock inside atomic op OK |
| OD-02 | Irreversible commit point | SaaS atomic: consume + dest binding + source grace authz |
| OD-03 | Consume + binding one DB transaction? | **Yes** on SaaS; local apply saga after |
| OD-04 | Authoritative SoR | SaaS commercial/licensing ledger |
| OD-05 | Idempotency retention | License lifetime / permanent |
| OD-06 | Authorization expiry pre-commit | **30 minutes** |
| OD-07 | Source post-rebind state | `migration_origin_grace` (Option B) |
| OD-08 | Grace capabilities | Traffic + backup/status/diagnostics |
| OD-09 | Grace prohibitions | No update/clone/Stage/migrate/rebind/export |
| OD-10 | Grace duration | Until Phase 21/22 explicit transition |
| OD-11 | Grace expiry trigger | Cutover / archive / admin rollback — not short auto |
| OD-12 | Source fully operational before 21? | Traffic yes; commercial/ops restricted |
| OD-13 | Call destination Production before cutover? | Only as `production_licensed_pre_cutover` |
| OD-14 | Canonical dest status name | `production_licensed_pre_cutover` |
| OD-15 | Dest cron before 21? | **Neutralized** business jobs |
| OD-16 | Outgoing email before 21? | **No** |
| OD-17 | Payment/webhook before 21? | **No** |
| OD-18 | Internal dest login? | **Yes** for technical validation only |
| OD-19 | Slot moves vs temporary second binding | **Logical move**; no second sellable slot |
| OD-20 | Temporary second binding representation | Staging identity ends; grace is not a slot |
| OD-21 | Duplicate slot detection | Ledger + LG + slot count assert |
| OD-22 | Refund after commit? | **No automatic** |
| OD-23 | Pre-cutover admin reversal? | Exceptional only with safety proof |
| OD-24 | Who authorizes reversal? | Designated admin role + dual control (confirm) |
| OD-25 | Reversal restores token qty? | Only if policy says yes + ledgered |
| OD-26 | Offline token consumption | Pre-issued single-use signed package only |
| OD-27 | Offline package expiry | Short (e.g. hours) |
| OD-28 | Offline reconciliation | **Mandatory** when connected |
| OD-29 | Stage rebind ordering | After dest bind + grace; before readiness |
| OD-30 | Optional Stage failure | **WARNING** |
| OD-31 | Mandatory Stage failure | **BLOCKED** |
| OD-32 | Source Stage accessible during grace? | Internal/protected; no public |
| OD-33 | Stage public routes | **Disabled** |
| OD-34 | Dest Stages run internally? | Allowed neutralized |
| OD-35 | Drift invalidating Phase 20 | Identity/UUID/digest/pair/readiness/public route |
| OD-36 | Phase 21 readiness validity | **24h** or drift invalidate |
| OD-37 | PASS/WARNING/BLOCKED | Per PHASE21_READINESS_MODEL |
| OD-38 | Integrations neutralized until 21+? | **Yes** |
| OD-39 | Source updates during grace? | **Blocked** |
| OD-40 | Source backup/restore? | Backup yes; restore-to-new-Production no |
| OD-41 | Dest backup after activation required? | **Recommended include** in Phase 20 |
| OD-42 | Post-activation dest backup in Phase 20? | **Yes recommend** |
| OD-43 | May create verified dest backup? | **Yes** |
| OD-44 | Rollback source to normal before 21? | Only via exceptional reversal |
| OD-45 | Manual support edit binding? | Deny by default; break-glass audited |
| OD-46 | Audit retention | Align License lifetime / compliance |
| OD-47 | Provider metadata retention | Minimal; no Stripe-as-truth |
| OD-48 | SaaS UI changes required later? | Likely; **frozen now** — separate auth |
| OD-49 | Progress weight | Propose **1** accounting; complexity VH |
| OD-50 | PASS with offline-only auth? | **No** for full commercial PASS unless reconcile proven |

Do not implement until owner closes OD-01…OD-50 for irreversible items.
