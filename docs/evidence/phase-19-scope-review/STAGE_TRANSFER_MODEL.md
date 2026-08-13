# STAGE_TRANSFER_MODEL.md

**Date:** 2026-08-02  
**Depends on:** Phase 17 Stage discovery; Phase 13 retention semantics

## Selection

| Rule | Default |
|------|---------|
| Selection mode | **Explicit select only** (nothing auto-included) |
| Expired Stages | **Always excluded** |
| Unselected | Not transferred; not purged on source |
| Display | May list all; select blocked for expired |

## Failure policy

| Stage marked | Failure effect |
|--------------|----------------|
| Optional (default) | **WARNING**; transfer may continue |
| Mandatory | **BLOCKED** until resolved or demoted |

## Payload

- Stage DB via dump helpers (Phase 16 Stage live patterns) and/or filestore as applicable  
- Bound to same transfer manifest under `stage.<id>` class  

## Abort

- Abort does not delete source Stages  
- Dest staging Stage copies follow abort preserve/exact-delete OD  
