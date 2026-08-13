# Migration Streaming and Staging Model — Phase 19

## Overview

Phase 19 implements **Direct Streaming Migration, Resumable Transfer, and Destination Staging** through a secure mTLS-based streaming protocol that enables multi-pass pre-synchronization with minimal downtime final transfer.

## Streaming Architecture

### Transfer Protocol
- **mTLS Channel**: Python TLS 1.2+ mutual authentication for secure payload streaming
- **Chunked Transfer**: Resumable multi-chunk transfer with manifest-based tracking
- **Multi-Pass Sync**: Pre-sync filestore and addon data to minimize final downtime
- **Write Freeze**: Application-level freeze using marker + state JSON during final sync

### Component Transfer Strategy

| Component | Strategy | Downtime Impact |
|-----------|----------|-----------------|
| Filestore | Multi-pass pre-sync + final delta | Minimal |
| Database | Single pg_dump transfer (no WAL/PITR) | Brief freeze period |
| Addons | Pre-sync + final config update | Minimal |
| Config/Secrets | Sanitized transfer (secrets excluded) | None |

## Destination Staging Model

### Staging Identity
- **Temporary ERP**: Isolated staging instance for validation
- **No Permanent Slot**: Staging uses temporary license allocation
- **No Public Routes**: Internal validation only, no external access
- **License Guard**: Full license validation during staging assembly

### Validation Pipeline
1. **Database Restore**: Full pg_restore with integrity checks
2. **Filestore Assembly**: Chunk reassembly with checksum validation
3. **ERP Internal Validation**: Container startup and basic functionality test
4. **License Guard Proof**: Temporary license activation for validation

## Security and Isolation

### Data Protection
- **mTLS Encryption**: End-to-end encrypted transfer channel
- **Secret Handling**: Source secrets never transferred (documented exclusions)
- **Multi-tenant Isolation**: Strict isolation between concurrent migrations
- **No SaaS Relay**: Direct source-to-destination transfer, no intermediate storage

### Threat Model Mitigations
- **Network Interruption**: Automatic resume from last completed chunk
- **Host Reboot**: State persistence with recovery from transfer manifest
- **Duplicate Prevention**: Migration token validation prevents duplicate actions
- **Abort Cleanup**: Complete rollback with exact cleanup of partial transfers

## Current Implementation Status

**Verdict: PARTIAL — Phase 19 implementation delivered with fixture/partial gaps**

### What Works (PASS)
- mTLS transfer channel with mutual authentication
- Chunked transfer with manifest-based resume
- Write freeze using application markers
- Multi-pass filestore pre-sync
- Database transfer with pg_dump/pg_restore
- Staging identity with license guard validation
- Security isolation and threat model mitigations

### Implementation Gaps (Fixture/Test Mode)
- Default e2e uses `SOVIEZ_MIG_TRANSFER_LOCAL=1` (local fixture mode)
- Write freeze uses `FREEZE_FIXTURE` in most tests (not live ERP gate)
- Reboot matrix defaults to `SOVIEZ_P19_SKIP_COLIMA_REBOOT=1` (state survival only)
- Destination ERP uses fixture `/web/login` HTML (not full container startup)
- Real pg_dump/pg_restore only when Docker environment available

## Progress Status

- **Implementation Progress**: 93% (no change)
- **Phase Status**: PARTIAL (fixtures/gaps documented)
- **Installer Version**: 0.19.0-phase19
- **Phase 20**: UNAUTHORIZED

The implementation provides a functional foundation with documented test fixtures and gaps that would need resolution for full production deployment.