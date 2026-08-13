# OWNER_DECISIONS.md

Status: **OPEN** — recommendations only; irreversible items require owner closure before Phase 21 implementation.

| ID | Decision | Recommendation | Status |
|----|----------|----------------|--------|
| OD-01 | Default cutover strategy | **Option C** hybrid | OPEN |
| OD-02 | Cutover final sync mandatory? | **Mandatory** final write freeze + DB/filestore delta before public route | OPEN |
| OD-03 | Final write-freeze maximum | **15 minutes** target (hard timeout fail-closed) | OPEN |
| OD-04 | Enter cutover_maintenance at DNS confirm vs instruction | **DNS confirm** | OPEN |
| OD-05 | Source read-only ERP vs maintenance page during propagation | **Maintenance page only** | OPEN |
| OD-06 | Dest backup between route activate and DNS | **Yes** | OPEN |
| OD-07 | Internal admin login before DNS via Host header | **Yes** | OPEN |
| OD-08 | Min propagation observation before health | **5 minutes** | OPEN |
| OD-09 | Propagation majority rule | **3/5 resolvers** | OPEN |
| OD-10 | Set production_dns_changed at attestation vs confirm | **Operator attestation** | OPEN |
| OD-11 | Block cutover if cert expires <24h | **BLOCKED**; WARNING if <7d | OPEN |
| OD-12 | DNS-01 vs HTTP-01 preference | **Operator choice** | OPEN |
| OD-13 | Auto source maintenance on DNS attestation | **Yes** | OPEN |
| OD-14 | ETA on maintenance page | **Optional** | OPEN |
| OD-15 | Max health retry window | **10 minutes** | OPEN |
| OD-16 | Authenticated login smoke mandatory | **BLOCKED on failure** | OPEN |
| OD-17 | Cron before or after mail | **After mail, before webhooks** | OPEN |
| OD-18 | Payment checklist attestation required | **Yes** | OPEN |
| OD-19 | Auto-rotate webhook secrets | **WARNING default** | OPEN |
| OD-20 | Meaningful dest writes threshold | **Any payment OR >10 docs** → Needs Action | OPEN |
| OD-21 | Post-rollback source state | **rollback_origin → migration_origin_grace** | OPEN |
| OD-22 | Default rollback window | **30 minutes** | OPEN |
| OD-23 | One-time window extension +30m | **Yes** with attestation | OPEN |
| OD-24 | Dual-control rollback after T0+15m | **Yes** if payments enabled | OPEN |
| OD-25 | Auto triggers after window expiry | **Advisory only** | OPEN |
| OD-26 | Enforced auto-rollback AR-03/AR-04 | **AR-04 enforced; AR-03 advisory** | OPEN |
| OD-27 | Propagation grace for health triggers | **120 seconds** | OPEN |
| OD-28 | Read-only source during propagation | **No — maintenance only** | OPEN |
| OD-29 | TTL lowering in DNS instruction | **Yes (document)** | OPEN |
| OD-30 | No Stages selected default | **Skip with WARNING** | OPEN |
| OD-31 | Mandatory Stage fail auto-rollback Production | **No — BLOCKED completion** | OPEN |
| OD-32 | Atomic SaaS RPC for traffic_owner | **Yes** | OPEN |
| OD-33 | Commit with optional-tier WARNING only | **Yes** | OPEN |
| OD-34 | Dual-control for cutover commit | **Yes** if payments | OPEN |
| OD-35 | Sign DNS instructions | **Yes** | OPEN |
| OD-36 | SaaS health egress detail level | **Codes only** | OPEN |
| OD-37 | Phase 21 readiness revalidation TTL | **24h** or drift invalidate | OPEN |
| OD-38 | LG gap: block vs WARN on cutover | **BLOCK public commit if LG deny** | OPEN |
| OD-39 | Provider live DNS adapter scope | **Optional local modules**; manual default | OPEN |
| OD-40 | Retire mig-subdomain landing post-cutover | **Owner choice**; default keep 7d | OPEN |
| OD-41 | Progress accounting weight | Propose **1**; complexity Very High | OPEN |
| OD-42 | Implementation authorization | **NOT until OD-01…OD-41 closed for irreversible** | OPEN |
| OD-43 | Cutover during business hours only | **WARNING** if off-hours | OPEN |
| OD-44 | Customer notification email before cutover | **Out of scope**; operator manual | OPEN |
| OD-45 | IPv6 AAAA cutover mandatory | **Optional WARNING** | OPEN |
| OD-46 | archive_ready signal at Phase 21 complete | **No** — Phase 22 only | OPEN |
| OD-47 | Reverse-migration automation in 21 | **No** — Needs Action manual | OPEN |
| OD-48 | SaaS UI cutover surfaces | **Frozen** — separate auth | OPEN |
| OD-49 | Mock ledger sufficient for certification | **Yes** for installer; SaaS parity separate | OPEN |
| OD-50 | PASS scope review with LG gap open | **Yes with OD-38 WARN/BLOCK policy documented** | OPEN |

Do not implement Phase 21 until owner closes irreversible items (OD-01, OD-05, OD-16, OD-20, OD-22, OD-32, OD-38, OD-42 minimum set).
