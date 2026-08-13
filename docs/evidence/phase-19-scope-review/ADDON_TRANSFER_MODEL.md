# ADDON_TRANSFER_MODEL.md

**Date:** 2026-08-02

## Default: registry-first

1. Inventory source installed/pinned addon digests  
2. On destination staging, **pull from private registry** (Phase 7) to matching digests  
3. Record pins in transfer manifest  

## Non-registry / unmanaged addons

| Case | Recommendation |
|------|----------------|
| Available in registry | Prefer registry pull (not binary ship) |
| Local-only / third-party drop | Optional transfer → WARNING; owner may mark mandatory |
| Broken/missing digest | WARNING or BLOCKED if required |

## Explicit non-goals

- Automatic transfer of **third-party business credentials** embedded in addon config (see secrets model)  
- Activating addons on **Production** (staging only)  
- Publishing unsigned addon blobs through SaaS  

## Verification

- Manifest digest match after pull/apply  
- Import/load smoke on staging technical validation path only  
