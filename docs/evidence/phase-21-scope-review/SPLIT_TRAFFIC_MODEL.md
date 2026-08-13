# SPLIT_TRAFFIC_MODEL.md

## Policy

**No intentional split traffic** (weighted DNS, geo split, canary percentage) in Phase 21 default.

Option C hybrid allows **transient** split during DNS propagation only — mitigated by source maintenance/read-only.

## Transient propagation epoch

| Resolver cohort | Resolves to | Serves |
|-----------------|-------------|--------|
| Early adopters | Destination | Destination ERP (post-health) |
| Lagging | Source | Source maintenance page (writes blocked) |

**Invariant:** Source must **not** accept writes during propagation if destination may serve reads.

## Forbidden patterns

| Pattern | Reason |
|---------|--------|
| Weighted RR 50/50 | Split-brain writes |
| SaaS traffic relay | Out of scope; single point of failure |
| Dual active ERP write paths | Data corruption |
| Sticky sessions spanning both | Session/auth corruption |

## Detection

Split-brain detector inputs:

- Public HTTP probe source IP vs destination IP both return ERP login (not maintenance) → **AR-04**.
- Write probe on source during maintenance → **AR-09**.

## Stage split traffic

Selected Stage public cutover is **all-or-nothing per Stage** — no partial Stage DNS weighting in Phase 21.

## OWNER DECISION REQUIRED

**OD-28:** Allow read-only source ERP during propagation vs maintenance-only?

**Recommendation:** **Maintenance-only** on Production FQDN (aligns OD-05).

**OD-29:** TTL lowering instruction included in DNS cutover doc?

**Recommendation:** **Yes** — recommend TTL=300 pre-switch in instruction addendum (documentation only).
