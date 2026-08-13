# Migration Chunk and Resume Protocol

## Overview

The chunked transfer protocol enables reliable, resumable migration of large datasets through fixed-size payload segments with automatic retry and recovery mechanisms.

## Chunking Strategy

### Chunk Size Configuration
- **Database**: 1MB chunks for pg_dump output streams
- **Filestore**: Variable size based on file boundaries (max 10MB per chunk)
- **Addons**: 256KB chunks for configuration and data files
- **Adaptive sizing**: Automatic adjustment based on network conditions

### Chunk Identification
```text
Chunk ID Format: {component}_{sequence}_{checksum}
Example: filestore_00001_a1b2c3d4e5f6
```

## Transfer Protocol

### Chunk Transmission
1. **Preparation**: Source creates chunk manifest with size and checksum
2. **Transmission**: mTLS-encrypted chunk payload sent to destination
3. **Verification**: Destination validates chunk checksum and size
4. **Acknowledgment**: Confirmation sent back to source for manifest update
5. **Next Chunk**: Process continues with next sequential chunk

### Network Failure Handling
- **Timeout Detection**: 30-second timeout per chunk transmission
- **Automatic Retry**: Up to 3 retry attempts per chunk with exponential backoff
- **Connection Recovery**: Re-establish mTLS channel and resume from last confirmed chunk
- **Partial Chunk Cleanup**: Remove incomplete chunks before retry

## Resume Mechanism

### State Persistence
- Transfer manifest tracks completed chunks across all components
- Source maintains transfer log with chunk status and timestamps
- Destination verifies chunk integrity during resume operations

### Resume Process
1. **Manifest Inspection**: Read current transfer state from manifest
2. **Integrity Check**: Verify all completed chunks have valid checksums
3. **Gap Analysis**: Identify missing or corrupted chunks requiring retransmission
4. **Resume Point**: Continue transfer from first incomplete chunk
5. **Cleanup**: Remove any partial or corrupted chunks before proceeding

### Multi-Component Resume
- Each component (database, filestore, addons) tracked independently
- Parallel resumption when network conditions allow
- Component completion gates prevent premature staging validation

## Error Recovery

### Chunk Corruption Detection
- Real-time checksum validation during transmission
- Post-transfer integrity verification before manifest update
- Automatic retransmission of corrupted chunks

### Transfer Failure Scenarios
- **Network Interruption**: Automatic resume after connectivity restored
- **Host Reboot**: State recovery from persistent manifest and transfer logs
- **Disk Full**: Pause transfer with notification and manual intervention required
- **Authentication Failure**: Re-establish mTLS credentials and resume

## Performance Optimization

### Parallel Transfer
- Multiple concurrent chunk streams when bandwidth allows
- Component prioritization (database > filestore > addons)
- Dynamic throttling based on destination resource availability

### Compression and Optimization
- Optional gzip compression for text-heavy chunks (database dumps)
- Delta transfers for filestore updates during multi-pass sync
- Deduplication for identical file chunks across addon transfers