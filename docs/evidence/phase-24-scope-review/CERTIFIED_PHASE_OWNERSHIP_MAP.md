# CERTIFIED_PHASE_OWNERSHIP_MAP.md

| Domain | Owner phase | Phase 24 may |
|--------|-------------|----------------|
| Entitlement resolver | 4 | Reuse; no fork |
| Device auth | 5 | Reuse |
| License slots | 6 | Reuse; no slot mutation product |
| Private Registry pull | 7 | **Harden** lockdown only |
| Offline install foundations | 8 | Reuse |
| Annual support | 9 | Reuse |
| Stage License | 10 / 10.5 | Reuse ticket crypto; **certify replay** |
| Multi-stage runtime | 11 | Reuse |
| SaaS UI | 11.5 | **Frozen — no edits** |
| Domain/SSL lifecycle | 12 | Reuse |
| Stage retention | 13 | Reuse |
| Operation engine | 14 | Reuse for any new ops |
| Update candidate/switch/rollback | 15 | **Harden** signed-only enforcement |
| Backup/restore | 16 | Reuse; secret-handling regression |
| Migration discovery/bootstrap | 17 | Reuse signed installer proofs |
| Migration DNS/routing | 18 | Reuse |
| Migration transfer | 19 | Reuse; no second transfer engine |
| Migration auth/rebind | 20 | Reuse token/replay invariants |
| Traffic cutover | 21 | Reuse |
| Source archive / retirement readiness | 22 | Reuse; **purge still not owned here** |
| Offline update bundles | 23 | Reuse; security regression only |
| Security hardening | **24** | **Owns** consolidation + CI + suite |
| Final certification / release checklist | **25** | Out of Phase 24 |

## Master-plan reconciliation (selected)

| Topic | Master plan | Repo now | Certified owner | Unresolved gap | P24? | P25? | Out? |
|-------|-------------|----------|-----------------|----------------|------|------|------|
| Installer lifecycle | modular `soviez.sh` | assemble/dist | 1–15+ | soft STRICT_SIG | harden | matrix | — |
| Activation | Phase 8 | `--new` path | 8 | plaintext activation key at rest | key hygiene | matrix | — |
| Licensing / slots | 4–6 | LG + SaaS | 4–6 | — | no fork | matrix | — |
| Updates | 15 | real Docker update | 15 | fixture token / soft sig | **yes** | matrix | — |
| Stage | 10–13 | stage engine | 10–13 | online/offline ticket cohesion | replay cert | matrix | — |
| Migration | 17–22 | migration stack | 17–22 | — | regression | matrix | — |
| Backup/restore | 16 | backup engine | 16 | full ERP restore WARNING (P22) | optional harden | matrix | — |
| Source retirement | 22 | archive | 22 | purge OPEN | **no** | no | purge separate |
| Offline bundles | 23 | offline_update | 23 | — | regression | matrix | — |
| Private Registry | 7 | pull_client | 7 | soft HOME docker check; CI | **yes** | matrix | — |
| Trust/signing | 7/15/23 | Ed25519/HMAC | 7/15/23 | fake-sig escapes outside cert | **yes** | matrix | — |
| SaaS | multi | RLS service_role server-side | multi | — | no UI | docs sync | frozen UI |
| License Guard | ERP | local | ERP | — | no redesign | matrix | — |
| Air-gapped | 8/17/23 | offline paths | 8/17/23 | — | regression | matrix | — |
| Recovery | 14–16 | ops engine | 14–16 | — | reboot where relevant | matrix | — |
| Security | 24 | partial suites | mixed | CI + consolidation | **yes** | — | — |
| Audit/evidence | all | evidence dirs | all | false PASS risk | finalizer hygiene | pack complete | — |
| Release closure | 25 | — | — | — | no | **yes** | — |
| Production rollout | — | — | — | — | no | no | **yes** (separate auth) |
| Documentation | ongoing | docs/ | — | stale self-update text | **yes** | sync | — |
| Technical debt | — | — | — | see debt file | classify | classify | — |
| Visual acceptance | 11.5 | deferred | 11.5 | owner | no | checklist item | — |
| Destructive purge | OPEN | denied in 22 | none | OD | **no** | **no** | **yes** until authorized |
