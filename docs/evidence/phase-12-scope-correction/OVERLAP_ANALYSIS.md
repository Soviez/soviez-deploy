# OVERLAP_ANALYSIS.md

## Former Phase 12 (Master Plan)

**Title:** Mandatory Stage domain/SSL  
**Objective:** Signed challenge; Try Again/Abort; valid cert gate for acceptance.  
**Scope:** DNS/SSL modules; remove Stage `force` acceptance; Production policy per owner.  
**Acceptance:** Stage incomplete without SSL validation pass.

## Phase 11 source of truth (already PASS)

| Capability | Evidence / model |
|------------|------------------|
| Mandatory unique Stage domain | `DOMAIN_SSL_MATRIX.md`, `STAGE_IDENTITY_AND_INVENTORY.md`, `MULTI_STAGE_RUNTIME_MODEL.md` |
| DNS validation | `DOMAIN_SSL_MATRIX.md` (fixture `SOVIEZ_STAGE_DNS_OK`) |
| Trusted CA SSL; self-signed rejected | `DOMAIN_SSL_MATRIX.md`, model §11 (`SSL_ISSUANCE_FAILED`) |
| Nginx Stage route stub | `DOMAIN_SSL_MATRIX.md` |
| Domain collision | `FAILURE_INJECTION.md` (`STAGE_DOMAIN_CONFLICT`) |
| State gates `domain_pending` / `ssl_pending` before complete | `STAGE_OPERATION_STATE_MACHINE.md` |
| Offline + connected Stage create | `OFFLINE_FULL_E2E.md`, `FINAL_REPORT.md` |
| Stage-origin certificate | `STAGE_ORIGIN_CERTIFICATION.md` |
| Multi-Stage isolated domains | `MULTI_STAGE_MATRIX.md` |
| Interrupt during SSL wait / recovery foundations | `DISCONNECT_RESUME_MATRIX.md`, `REBOOT_RECOVERY_E2E.md` |

## Overlap conclusion

Former Phase 12 **re-stated** Phase 11 initial provisioning and acceptance gates. That is incorrect for a successor phase.

## Non-overlap (legitimate Phase 12)

- Certificate **renewal / rotation / expiry monitoring** after issuance  
- Durable operational DNS challenge **retry / Abort / resume / replay** hardening beyond first create  
- Nginx **ownership, `nginx -t`, atomic promote, rollback, orphan reconciliation** as long-running ops  
- **Production** domain/SSL policy (owner-gated)  
- Local **health/repair** without mandatory SaaS  
- Residual unsafe **force** bypass removal if any remain after Phase 11  

## Decision

Retitle and rescope Phase 12 to lifecycle hardening; keep Phase 11 as owner of initial Stage domain/SSL.
