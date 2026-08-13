# DESTINATION_VALIDATION_MODEL.md

**Date:** 2026-08-02

## Purpose

Prove destination **staging** is coherent after transfer — not Production certification (Phase 21).

## Allowed checks (technical)

- Manifest completeness: required classes `done`  
- DB restore verify (Phase 16-style checks against staging)  
- Filestore digest spot-checks / full verify per OD  
- Addon pins present  
- Staging identity isolation assertions (no slot; no public login route)  
- Pair still VALID; token still unreserved/unconsumed  

## Disallowed as Phase 19 “PASS”

- Public `/web/login` success on Production domain  
- Customer UAT sign-off as Production  
- Token consume / license migrate RPC success  

## Ready-for-20 report

Emit **PASS / WARNING / BLOCKED** (`TRANSFER_STATE_MACHINE.md`). WARNING examples: optional Stage fail, unmanaged addon skip, RESTORE_TESTED absent on pinned backup. BLOCKED: required payload fail, capacity, pair invalid, freeze timeout without consistent final apply.
