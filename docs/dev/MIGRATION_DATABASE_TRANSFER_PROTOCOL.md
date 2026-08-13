# Migration Database Transfer Protocol

## Overview

The database transfer protocol implements secure, consistent migration of PostgreSQL databases using pg_dump/pg_restore with transactional integrity and minimal downtime through write freeze coordination.

## Transfer Strategy

### Database Dump Process
- **Single Transaction**: pg_dump with `--single-transaction` for consistency
- **Custom Format**: Use `-Fc` (custom format) for optimal compression and restore performance
- **Exclude Tables**: Skip temporary and cache tables to reduce transfer size
- **Schema + Data**: Full schema and data dump for complete migration

### Dump Command Template
```bash
pg_dump -h $SOURCE_HOST -U $DB_USER -d $DB_NAME \
  --single-transaction \
  --format=custom \
  --compress=9 \
  --exclude-table=temp_* \
  --exclude-table=cache_* \
  --file=database_dump.pgc
```

## Write Freeze Integration

### Pre-Dump Freeze
1. **Application Marker**: Create `/tmp/soviez_write_freeze.marker`
2. **State Capture**: Save current application state to JSON
3. **Connection Drain**: Allow existing transactions to complete (30s timeout)
4. **Freeze Verification**: Confirm no new write operations

### Dump Execution
- Begin pg_dump immediately after write freeze confirmation
- Monitor dump progress and estimated completion time
- Maintain freeze state throughout dump duration
- Capture dump metadata (size, checksum, completion time)

### Freeze Release
- Release write freeze after successful dump completion
- Remove freeze marker and restore normal operations
- Log freeze duration for downtime tracking

## Chunked Transfer

### Dump Streaming
- Stream pg_dump output directly to chunked transfer protocol
- 1MB chunk size for optimal network utilization
- Real-time compression and checksum calculation
- Parallel chunk transmission when bandwidth allows

### Progress Tracking
- Chunk-level progress reporting with ETA calculation
- Transfer rate monitoring and throttling
- Network interruption detection and resume capability
- Integrity verification for each transferred chunk

## Destination Restore

### Pre-Restore Setup
1. **Database Creation**: Create clean target database
2. **User Permissions**: Configure database users and permissions
3. **Extension Install**: Install required PostgreSQL extensions
4. **Validation**: Verify database readiness for restore

### Restore Process
```bash
pg_restore -h $DEST_HOST -U $DB_USER -d $TARGET_DB \
  --clean \
  --if-exists \
  --no-owner \
  --no-privileges \
  --single-transaction \
  --verbose \
  database_dump.pgc
```

### Post-Restore Validation
- **Row Count Verification**: Compare table row counts between source and destination
- **Schema Integrity**: Verify all tables, indexes, and constraints
- **Data Sampling**: Random sampling validation for data integrity
- **Performance Check**: Basic query performance validation

## Error Handling

### Dump Failures
- **Lock Timeout**: Retry with longer lock timeout if dump fails due to blocking
- **Disk Space**: Monitor available space and fail gracefully if insufficient
- **Connection Loss**: Restart dump process and extend freeze if necessary
- **Permission Errors**: Validate database permissions before retry

### Transfer Failures
- **Network Interruption**: Resume from last completed chunk using manifest
- **Corruption Detection**: Rechecksum and retransmit corrupted chunks
- **Timeout Handling**: Progressive timeout increases for large chunks
- **Authentication Issues**: Re-establish mTLS channel and resume

### Restore Failures
- **Schema Conflicts**: Clean restore with conflict resolution
- **Permission Issues**: Adjust ownership and privileges post-restore
- **Extension Missing**: Install required extensions and retry
- **Disk Space**: Fail gracefully with cleanup recommendations

## Security Considerations

### Data Protection
- mTLS encryption for all database payload transfers
- No intermediate storage of database dumps on third-party systems
- Secure cleanup of temporary dump files after transfer completion
- Database credentials isolated and never transmitted

### Access Control
- Source database access limited to read-only dump user
- Destination database isolated during staging
- Transfer logs exclude sensitive data patterns
- Audit trail for all database operations during migration