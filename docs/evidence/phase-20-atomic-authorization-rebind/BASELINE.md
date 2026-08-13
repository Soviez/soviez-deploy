# BASELINE — Phase 20 Implementation Baseline

## Pre-Implementation State

**Date:** 2026-08-02 (start of Phase 20 implementation)  
**Previous Version:** `0.19.0-phase19`  
**Previous SHA256:** `eb7f29235d352db6cfe47a0c065d3eaa81104047d80ab7e3ab351dd6f51c25fc`  
**Progress Before:** 95%  

## System State Before Phase 20

### Existing Migration Capabilities
- ✅ **Phase 17**: Discovery, trust pairing, destination bootstrap
- ✅ **Phase 18**: Maintenance landing, domain validation, routing readiness
- ✅ **Phase 19**: Direct streaming transfer, resumable chunks, destination staging, write freeze
- ❌ **Atomic authorization**: No canonical token consume + rebind commit
- ❌ **Source grace / dest pre-cutover**: Not implemented
- ❌ **Phase 21 readiness gate**: Not implemented

### Commercial State Before Phase 20
```text
Token eligibility: read-only (Phase 17)
Token consume: legacy wallet paths (begin_license_migration / consume_ip_migration_token)
Dual truth: wallet credits vs commercial_grants.migration_token (unreconciled burn)
```

### Key Limitations
- No atomic IFF commit (token ↔ binding ↔ grace)
- No anti-split-brain enforcement post-authorization
- No offline authorization package flow
- Phase 21 cutover unauthorized (unchanged)

## Architecture Before Phase 20

Missing components now under implementation:
1. `commit_migration_authorization` SaaS RPC + fixture ledger
2. Installer modules: `authorization/`, `token/`, `rebind/`, `activation/`, `phase21_readiness/`
3. Evidence and certification suites (pending PASS)

## Target State

**Installer:** `0.20.0-phase20`  
**Progress on PASS:** 96% (weight 1)  
**Phase 21:** UNAUTHORIZED
