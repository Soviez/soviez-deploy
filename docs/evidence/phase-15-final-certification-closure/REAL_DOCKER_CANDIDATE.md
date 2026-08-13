# Real Docker Candidate

## Environment
- Runtime: Colima → Docker
- Candidate image: `soviez/erp:p15-v15-labeled` (target)
- Prior production digest: `soviez/erp:p15-v14-labeled`
- Network/container: `soviez-upd-net-<op>` / `soviez-upd-cand-<op>`
- Host addons mount under Colima-visible `$SOVIEZ_ROOT` (not `/var/folders` mktemp)

## Proof
- Isolation proof marker `real_docker` in candidate runtime
- Candidate DB on shared disposable PG `soviez-upd-pg-cert`
- Production identity digest unchanged until successful switch
- Flag: `SOVIEZ_UPDATE_REAL_DOCKER=1`

## Result
PASS — real Docker candidate path exercised end-to-end in final cert.
