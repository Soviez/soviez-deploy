# Migration Transfer Status and Recovery

## Overview

This guide explains how to monitor migration transfer progress, understand status messages, and recover from transfer interruptions or failures.

## Checking Transfer Status

### Basic Status Check
```bash
# Check current migration status
./soviez.sh migration status

# Output example:
Migration Status: ACTIVE
Migration ID: mig-20260802-153000
Phase: Database Transfer (2 of 4)
Overall Progress: 45%
Estimated Time Remaining: 12 minutes
```

### Detailed Progress View
```bash
# Detailed progress breakdown
./soviez.sh migration progress --detailed

# Output example:
Migration Progress Details
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Migration ID: mig-20260802-153000
Started: 2026-08-02 15:30:00 UTC
Duration: 18m 32s

Component Transfer Status:
┌─────────────┬────────────┬─────────────┬──────────┬─────────────┐
│ Component   │ Status     │ Progress    │ Size     │ Speed       │
├─────────────┼────────────┼─────────────┼──────────┼─────────────┤
│ Database    │ Active     │ 67% (1.8GB) │ 2.7GB    │ 12.3 MB/s   │
│ Filestore   │ Completed  │ 100% (450MB)│ 450MB    │ Completed   │
│ Addons      │ Completed  │ 100% (12MB) │ 12MB     │ Completed   │
│ Staging     │ Pending    │ 0%          │ -        │ -           │
└─────────────┴────────────┴─────────────┴──────────┴─────────────┘

Network Status:
• mTLS Connection: Established ✓
• Current Speed: 12.3 MB/s
• Average Speed: 15.1 MB/s
• Packets Lost: 0.02%

System Status:
• Source Write Freeze: Active (8m 15s)
• Destination Staging: Preparing
• Available Disk: 45.2GB remaining
```

### Real-Time Monitoring
```bash
# Watch transfer progress in real-time
./soviez.sh migration watch

# Continuous output updates every 30 seconds
# Press Ctrl+C to exit monitoring
```

## Understanding Status Messages

### Transfer Phases
```text
Phase 1: Pre-Sync
• Files and addons transfer while system remains operational
• May take several hours depending on data size
• No downtime during this phase

Phase 2: Database Transfer  
• Brief maintenance window (write freeze active)
• Complete database dump and transfer
• Typically 5-30 minutes depending on database size

Phase 3: Final Sync
• Transfer any files changed during database transfer
• Usually completes quickly due to pre-sync

Phase 4: Staging Validation
• Restore and validate data on destination
• Test system functionality
• No impact on source system
```

### Component Status Indicators

| Status | Meaning |
|--------|---------|
| `Pending` | Component transfer not yet started |
| `Preparing` | Setting up for transfer (creating manifests, etc.) |
| `Active` | Currently transferring data |
| `Paused` | Transfer temporarily paused (resumable) |
| `Completed` | Component transfer finished successfully |
| `Failed` | Component transfer failed (requires intervention) |
| `Aborted` | Transfer was manually cancelled |

### System Status Indicators

| Indicator | Meaning |
|-----------|---------|
| `Source Write Freeze: Active` | Source system in read-only mode |
| `mTLS Connection: Established` | Secure connection active |
| `Destination Staging: Ready` | Destination prepared for data |
| `Network Health: Good` | Network conditions stable |
| `Disk Space: Sufficient` | Adequate storage available |

## Recovery from Interruptions

### Automatic Recovery
The migration system automatically handles common interruptions:

**Network Disconnections**
- Detects connection loss within 30 seconds
- Automatically attempts reconnection every 60 seconds
- Resumes from last completed chunk when reconnected

**Server Restarts**
- Transfer state saved to disk every 30 seconds
- Automatic state recovery on system startup
- Resume from exact point of interruption

**Process Crashes**
- Migration process monitored by system supervisor
- Automatic process restart with state recovery
- Transfer continues from last checkpoint

### Manual Recovery Commands

**Check Recovery Status**
```bash
# Check if migration can be resumed
./soviez.sh migration check-resume

# Output example:
Migration Recovery Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━
Migration ID: mig-20260802-153000
Status: Recoverable
Last Checkpoint: 2026-08-02 15:48:32 UTC
Progress at Interruption: 67%
Completed Components: filestore, addons
Incomplete Components: database (67%), staging (0%)
Recovery Action: Resume available
```

**Resume Transfer**
```bash
# Resume interrupted migration
./soviez.sh migration resume

# Resume with specific migration ID
./soviez.sh migration resume --id mig-20260802-153000

# Resume with integrity check
./soviez.sh migration resume --verify-integrity
```

**Force Recovery**
```bash
# Force recovery from corrupted state (use with caution)
./soviez.sh migration recover --force

# Recovery with cleanup of partial data
./soviez.sh migration recover --cleanup
```

## Handling Transfer Failures

### Identifying Failure Causes

**Network Issues**
```bash
# Test network connectivity
./soviez.sh migration test-network

# Detailed network diagnostics
./soviez.sh migration diagnose --network
```

**Storage Issues**
```bash
# Check disk space on both systems
./soviez.sh migration diagnose --storage

# Clean up temporary files
./soviez.sh migration cleanup --temp-files
```

**Authentication Issues**
```bash
# Test mTLS certificate validity
./soviez.sh migration test-auth

# Refresh migration certificates
./soviez.sh migration refresh-certs
```

### Recovery Strategies

**Partial Transfer Recovery**
```bash
# Resume from specific component
./soviez.sh migration resume --component database

# Skip corrupted component (expert use only)
./soviez.sh migration resume --skip-component filestore
```

**Clean Restart**
```bash
# Abort current transfer and clean up
./soviez.sh migration abort --cleanup

# Start fresh migration
./soviez.sh migration start --destination HOST
```

### Error Code Reference

| Error Code | Description | Resolution |
|------------|-------------|------------|
| `NET_001` | Connection timeout | Check network connectivity |
| `NET_002` | Authentication failure | Verify certificates and tokens |
| `DISK_001` | Insufficient storage | Free up disk space |
| `DISK_002` | Permission denied | Check file system permissions |
| `DB_001` | Database connection failed | Verify database accessibility |
| `DB_002` | pg_dump failed | Check database integrity |
| `CHUNK_001` | Chunk corruption detected | Automatic retry usually resolves |
| `FREEZE_001` | Write freeze timeout | Check for blocking transactions |

## Troubleshooting Common Issues

### Slow Transfer Performance

**Diagnosis**
```bash
# Check network performance
./soviez.sh migration diagnose --performance

# Monitor resource usage
./soviez.sh migration monitor --resources
```

**Solutions**
- Schedule transfer during off-peak hours
- Close unnecessary applications using bandwidth
- Check for network congestion or interference
- Consider upgrading network connection

### Transfer Stuck or Hanging

**Diagnosis**
```bash
# Check for stuck processes
./soviez.sh migration diagnose --processes

# View detailed transfer logs
./soviez.sh migration logs --tail 100
```

**Solutions**
```bash
# Gentle restart of stuck component
./soviez.sh migration restart --component database

# Force restart if needed
./soviez.sh migration restart --force

# Complete transfer restart
./soviez.sh migration abort
./soviez.sh migration start --resume-from-backup
```

### Write Freeze Timeout

**Understanding the Issue**
- Write freeze protects data consistency during database transfer
- Timeout occurs if freeze exceeds maximum duration (30 minutes)
- Usually caused by long-running database transactions

**Resolution**
```bash
# Check active database connections
./soviez.sh migration diagnose --database-locks

# Release write freeze (emergency only)
./soviez.sh migration release-freeze --emergency

# Restart transfer with adjusted timeout
./soviez.sh migration start --freeze-timeout 45m
```

## Monitoring and Alerts

### Setting Up Notifications
```bash
# Enable email notifications for transfer events
./soviez.sh migration config --notify-email admin@company.com

# Set up webhook notifications
./soviez.sh migration config --notify-webhook https://hooks.company.com/migration

# Configure notification events
./soviez.sh migration config --notify-events "started,completed,failed,progress"
```

### Log File Locations
```text
Transfer Logs: /opt/soviez/logs/migration/
├── migration-20260802-153000.log      # Main transfer log
├── network-20260802-153000.log        # Network activity log
├── database-20260802-153000.log       # Database transfer log
└── security-20260802-153000.log       # Security and auth log
```

### Getting Support

**Information to Collect**
1. Migration ID and current status
2. Error messages from logs
3. Network connectivity test results
4. System resource availability
5. Timeline of events leading to issue

**Support Commands**
```bash
# Generate comprehensive support bundle
./soviez.sh migration support-bundle

# Test all migration prerequisites
./soviez.sh migration preflight-check --comprehensive

# Export configuration for review
./soviez.sh migration export-config --sanitized
```