# CUTOVER_STRATEGY_OPTIONS.md

## Context

Phase 21 must transfer **Production customer traffic** from source to destination without split-brain, with rollback inside a bounded window. Three strategies evaluated.

---

## Option A — DNS-first (big-bang)

**Sequence:** Authoritative DNS switch → destination serves immediately → source maintenance after propagation.

| Pros | Cons |
|------|------|
| Minimal steps | Destination may be unready when DNS propagates |
| Familiar operator pattern | Health validation lagging DNS causes customer impact |
| | Hard rollback if dest ERP/nginx not pre-validated |

**Verdict:** **Reject as default** — violates health-before-traffic_owner invariant.

---

## Option B — Destination-first (nginx/TLS ready, DNS last)

**Sequence:** Activate dest Production route + TLS on destination IP/FQDN → validate via hosts file / direct IP smoke → DNS switch → traffic_owner flip.

| Pros | Cons |
|------|------|
| Strong pre-DNS validation | Requires direct access smoke (not fully public until DNS) |
| Clear commit boundary | Operator must understand two validation epochs |
| Aligns with Phase 20 internal activation | |

**Verdict:** **Strong component** — embed in hybrid default.

---

## Option C — Provider-neutral hybrid (recommended)

**Sequence:**

1. **Destination route activate** — Production nginx upstream to ERP on destination (still unreachable via Production DNS).
2. **Production TLS valid** on destination for Production FQDN.
3. **Authoritative DNS switch** — manual instructions; operator executes out of band.
4. **Source maintenance/read-only** during propagation (serves maintenance page; blocks writes).
5. **Public health PASS** on Production domain resolving to destination.
6. **`traffic_owner=destination`** only after step 5.
7. **No SaaS traffic relay** — DNS and nginx are the control plane.

| Pros | Cons |
|------|------|
| Health-gated traffic ownership | More steps; longer runbook |
| Source still serves until maintenance epoch | Requires disciplined operation engine |
| Manual DNS first-class (provider-neutral) | Provider adapters optional, not required |
| Reuses Phase 12 nginx/SSL + Phase 18 routing plan | |
| Rollback window meaningful before dest writes | |

**Verdict:** **Recommend Option C** as canonical default (OD-01).

---

## Comparison matrix

| Criterion | A DNS-first | B Dest-first | C Hybrid |
|-----------|-------------|--------------|----------|
| Health before public traffic_owner | Weak | Strong | **Strongest** |
| Split-brain risk | High | Medium | **Low** |
| Rollback clarity | Medium | Strong | **Strong** |
| Manual DNS support | Yes | Yes | **First-class** |
| SaaS relay required | No | No | **No** |
| Phase 18/12 reuse | Partial | High | **High** |

---

## OWNER DECISION REQUIRED

**OD-01:** Adopt Option C (provider-neutral hybrid) as default cutover strategy?

**Recommendation:** **Yes** — aligns with Phase 20 anti-split-brain model and commit boundary in `COMMIT_BOUNDARY.md`.

Alternatives (A or B-only) require explicit owner waiver and revised rollback model.
