# License Guard / License Slot Bootstrap Boundary — Phase 17

## Requirements

- No second active permanent Production  
- No permanent destination activation  
- No duplicated licensed runtime  
- No Guard bypass / fake activation  
- Source remains valid and active  
- Destination may run installer, diagnostics, Docker, neutral DB-free checks only  
- Destination identity is temporary / non-sellable  
- Later activation requires approved migration flow (Phase 21)  
- Abort cleans temporary identity safely  

## Mapping to existing primitives

| Primitive | Phase 17 use |
|-----------|--------------|
| `--new` full SM | **Do not** run as migrate |
| License Slot reserve/bind | **Do not** permanent bind |
| Device Authorization | Allowed for temporary host |
| Update LG candidate (`SOVIEZ_MIGRATION_SECRET`) | Same-host only — **not** cross-host Production |
| ERP activate ORM | Phase **21** |

## What destination may host before activation

| Allowed | Forbidden |
|---------|-----------|
| Signed installer | Sellable Production ERP |
| Diagnostics / capacity checks | Customer database |
| Optional image pull (OD-22) | Permanent fingerprint bind as Production |
| Bootstrap ID record | Claiming License Guard “activated” |
| Maintenance landing | Phase **18** only |

## Abort

Revoke temporary bootstrap identity; do not release unrelated Production slots; do not deactivate source License.
