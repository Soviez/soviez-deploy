# CORRECTED_SCOPE.md

## Title correction

| | Text |
|---|------|
| **Older plan title** | Destination maintenance landing and signed DNS validation |
| **Corrected title** | **Maintenance Landing, Signed Domain Validation, and Migration Routing Readiness** |
| **Why rename** | Older title omitted routing-plan readiness and implied “destination maintenance” as the whole phase. Corrected title names three deliverables: landing, signed domain validation, and routing readiness — without cutover/transfer. |

## Corrected objective

Prepare the **domain, maintenance-landing, TLS, and routing control plane** required for later migration cutover, bound to an exact Phase 17 migration pair, **without** transferring business data, enabling source cutover maintenance, mutating Production DNS/routing, reserving/consuming Migration Token, or activating destination ERP as Production.

## Inclusions

- Exact migration-pair targeting  
- Migration-domain planning & source-domain inspection (read-only)  
- Destination reverse-proxy preparation  
- Neutral maintenance landing  
- Signed DNS challenge + observation/validation + ownership proof  
- Pre-cutover TLS for **migration subdomain**  
- Routing-plan generation (no cutover)  
- Landing preview, connectivity validation, readiness report  
- Try Again / Abort  
- Operation-engine integration, reboot recovery  
- Offline/manual DNS instruction path  
- Docs and tests  

## Exclusions (later phases)

| Exclusion | Phase |
|-----------|-------|
| DB/filestore/addon/config/Stage transfer | 19 |
| Source maintenance activation for real cutover | 21 |
| Production traffic cutover | 21 |
| Permanent destination Production activation | 20/21 |
| Migration Token reserve/consume | 20 |
| Source License deactivation / shutdown / archive / purge | 20–22 |
| Final post-migration login certification | 21+ |
| Automated transfer start | 19 |
| Unrelated domain ownership changes | never |

## Binding future outcome (implementation acceptance banner)

```text
MIGRATION PAIR — VALID
DOMAIN PLAN — COMPLETE
DNS CHALLENGE — VERIFIED
DESTINATION LANDING — READY
TLS — VALID
ROUTING PLAN — READY
SOURCE TRAFFIC — UNCHANGED
NO BUSINESS DATA TRANSFERRED
MIGRATION TOKEN — NOT RESERVED / NOT CONSUMED
DESTINATION ERP PRODUCTION — NOT ACTIVATED
```

## Boundary vs 19–21

- **→ Phase 19:** routing plan + pair + landing TLS/landing as inputs; Phase 19 starts streaming only after separate authorization.  
- **→ Phase 20:** token burn / License rebind / activation — not Phase 18.  
- **→ Phase 21:** Production-domain cutover, source maintenance page on Production domain, traffic switch.  
