# Migration Transfer Manifest Protocol

## Overview

The transfer manifest protocol provides resumable transfer capabilities through structured metadata tracking of chunked payload transfers between source and destination instances.

## Manifest Structure

### Transfer Manifest Format
```json
{
  "transfer_id": "uuid",
  "source_instance": "instance_id",
  "destination_host": "hostname",
  "created_at": "iso8601_timestamp",
  "components": {
    "database": {
      "status": "pending|in_progress|completed|failed",
      "chunks": [
        {
          "chunk_id": 1,
          "size_bytes": 1048576,
          "checksum_sha256": "hash",
          "status": "completed",
          "transferred_at": "iso8601_timestamp"
        }
      ]
    },
    "filestore": {
      "status": "pending|in_progress|completed|failed",
      "total_files": 1250,
      "chunks": []
    },
    "addons": {
      "status": "pending|in_progress|completed|failed", 
      "addon_count": 5,
      "chunks": []
    }
  },
  "write_freeze": {
    "status": "inactive|active|released",
    "frozen_at": "iso8601_timestamp",
    "marker_file": "/path/to/freeze.marker"
  }
}
```

## Manifest Operations

### Creation and Initialization
- Manifest created during transfer planning phase
- Initial component status set to `pending`
- Transfer ID generated for tracking and resumption
- Source instance validation and component enumeration

### Update Protocol
- Atomic updates for chunk completion status
- Checksum validation before marking chunks complete
- Status transitions logged with timestamps
- Failure states captured with error details

### Resume Logic
- Manifest inspection determines completed vs pending chunks
- Transfer resumes from first incomplete chunk per component
- Integrity verification of existing chunks before proceeding
- Cleanup of partial chunks from interrupted transfers

## Integration Points

### Write Freeze Coordination
- Manifest tracks freeze marker creation and release
- Application-level freeze status synchronized with transfer state
- Timeout handling for stuck freeze states

### Destination Assembly
- Manifest provides chunk sequence for reassembly
- Integrity verification using stored checksums
- Component completion gates for staging validation

## Security Considerations

- Manifest stored securely on both source and destination
- Tamper detection through manifest checksums
- Access restricted to migration service processes
- Cleanup procedures for failed or aborted transfers