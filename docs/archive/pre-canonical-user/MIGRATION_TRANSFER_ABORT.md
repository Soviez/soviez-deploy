# Migration Transfer Abort Guide

## Overview

This guide explains how to safely cancel a migration transfer, understand the cleanup process, and restore your system to normal operation when a migration needs to be aborted.

## When to Abort a Migration

### Valid Reasons for Aborting
- **Extended Transfer Time**: Transfer taking longer than acceptable maintenance window
- **Network Issues**: Persistent connectivity problems causing repeated failures
- **System Resources**: Source or destination system running low on resources
- **Business Requirements**: Urgent need to restore normal system operations
- **Technical Issues**: Discovery of data corruption or system incompatibilities
- **Emergency Situations**: Critical business operations requiring immediate system access

### Before You Abort
Consider these alternatives before aborting:

```bash
# Check if transfer can be paused instead of aborted
./soviez.sh migration pause

# Extend maintenance window if possible
./soviez.sh migration extend-window --duration 2h

# Check estimated time remaining
./soviez.sh migration status --detailed
```

## Aborting a Migration

### Graceful Abort (Recommended)
```bash
# Initiate graceful abort with cleanup
./soviez.sh migration abort

# Abort with reason for audit trail
./soviez.sh migration abort --reason "network_issues"

# Abort with extended cleanup time
./soviez.sh migration abort --cleanup-timeout 30m
```

**What Happens During Graceful Abort:**
1. **Active Transfers Stop**: Current chunk transfers complete, then stop
2. **Write Freeze Release**: Source system returns to normal operation
3. **Cleanup Process**: Temporary files and staging environments removed
4. **State Reset**: Migration state cleared for potential future attempts

### Emergency Abort
```bash
# Immediate abort without waiting for current operations
./soviez.sh migration abort --immediate

# Emergency abort with force cleanup
./soviez.sh migration abort --emergency --force-cleanup
```

**Use emergency abort only when:**
- System is unresponsive to graceful abort
- Critical security incident requires immediate action
- Hardware failure requires immediate attention

## Abort Process Stages

### Stage 1: Transfer Termination
```text
Aborting Migration: mig-20260802-153000
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[1/4] Stopping Active Transfers
├── Database Transfer: Stopping gracefully... ✓
├── Filestore Transfer: Completing current chunk... ✓
├── Addon Transfer: Already completed ✓
└── Network Connections: Closing mTLS channels... ✓

Estimated completion: 2-3 minutes
```

### Stage 2: Source System Restoration
```text
[2/4] Restoring Source System
├── Write Freeze: Releasing... ✓
├── Database Locks: Clearing... ✓
├── Temporary Files: Removing... ✓
└── Normal Operations: Restored ✓

Source system fully operational
```

### Stage 3: Destination Cleanup
```text
[3/4] Cleaning Destination System
├── Staging Containers: Stopping and removing... ✓
├── Staging Database: Dropping... ✓
├── Partial Files: Removing... ✓
├── Temporary Licenses: Revoking... ✓
└── Transfer Chunks: Cleaning... ✓

Destination system cleaned
```

### Stage 4: Security and Audit
```text
[4/4] Security and Audit Cleanup
├── mTLS Certificates: Cleaning temporary certs... ✓
├── Transfer Logs: Securing and archiving... ✓
├── Sensitive Data: Secure deletion... ✓
└── Audit Trail: Recording abort event... ✓

Abort completed successfully
```

## Monitoring Abort Progress

### Real-Time Abort Status
```bash
# Watch abort progress in real-time
./soviez.sh migration abort-status --watch

# Check abort completion
./soviez.sh migration abort-status
```

### Abort Progress Example
```text
Migration Abort Status
━━━━━━━━━━━━━━━━━━━━━━━━━━
Migration ID: mig-20260802-153000
Abort Started: 2026-08-02 16:15:30 UTC
Duration: 3m 45s

Progress: [████████████████] 100%
Status: Cleanup Completed

Cleanup Summary:
├── Source System: Fully restored ✓
├── Destination System: Cleaned ✓  
├── Network Security: Cleaned ✓
├── Temporary Data: Securely deleted ✓
└── Audit Logs: Archived ✓

System Status: Normal Operations Resumed
```

## Post-Abort Verification

### System Health Check
```bash
# Comprehensive system health check after abort
./soviez.sh migration post-abort-check

# Verify source system fully operational
./soviez.sh system health-check --comprehensive
```

### Expected Health Check Results
```text
Post-Abort System Health Check
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Source System Status:
├── Database: Operational ✓
├── Web Interface: Responsive ✓
├── File Operations: Working ✓
├── User Sessions: Active ✓
├── Background Jobs: Running ✓
└── Write Operations: Enabled ✓

Cleanup Verification:
├── No Migration Processes: Confirmed ✓
├── No Write Freeze: Confirmed ✓
├── No Temporary Files: Confirmed ✓
├── No Staging Data: Confirmed ✓
└── Normal Resource Usage: Confirmed ✓

Result: System fully restored to pre-migration state
```

## Handling Abort Failures

### If Abort Process Hangs
```bash
# Check abort process status
./soviez.sh migration abort-diagnose

# Force abort completion
./soviez.sh migration abort --force

# Emergency manual cleanup
sudo ./soviez.sh migration emergency-cleanup --migration-id mig-20260802-153000
```

### Manual Cleanup Procedures

**If Automated Cleanup Fails:**

1. **Remove Write Freeze**
```bash
# Check for active freeze
ls -la /tmp/soviez_write_freeze.marker

# Remove freeze marker if present
sudo rm -f /tmp/soviez_write_freeze.marker
sudo rm -f /tmp/soviez_freeze_state.json
```

2. **Clean Temporary Files**
```bash
# Remove migration temporary files
sudo find /tmp -name "*mig-20260802-153000*" -delete

# Clean up transfer chunks
sudo rm -rf /tmp/transfer_chunks_*
```

3. **Verify Database Access**
```bash
# Test database write operations
./soviez.sh system test-database-write

# Restart database service if needed
sudo systemctl restart postgresql
```

4. **Check System Services**
```bash
# Verify all services running
sudo systemctl status odoo
sudo systemctl status nginx
sudo systemctl status postgresql
```

## Re-attempting Migration After Abort

### Preparation for Retry
```bash
# Wait for system stabilization
sleep 300  # 5 minutes

# Perform comprehensive health check
./soviez.sh system health-check --comprehensive

# Clear any residual migration state
./soviez.sh migration clear-state
```

### Addressing Root Causes
Before retrying, address the issues that caused the abort:

**Network Issues**
- Test network connectivity: `./soviez.sh migration test-network`
- Check bandwidth availability during planned migration window
- Consider network optimization or scheduling changes

**Resource Constraints**  
- Free up disk space: `./soviez.sh system cleanup --aggressive`
- Close unnecessary applications and services
- Consider system upgrades if resources consistently insufficient

**Time Constraints**
- Plan longer maintenance window
- Consider pre-sync optimization: `./soviez.sh migration pre-sync --optimize`
- Schedule during low-activity periods

### Starting New Migration
```bash
# Start fresh migration with lessons learned
./soviez.sh migration start --destination DEST_HOST \
  --timeout-extended \
  --pre-sync-aggressive \
  --monitor-resources

# Or resume from backup if available
./soviez.sh migration start --resume-from-backup BACKUP_ID
```

## Abort Impact Assessment

### Business Impact
- **Downtime Duration**: Calculate total system downtime during abort process
- **User Impact**: Assess impact on active users and business processes  
- **Data Integrity**: Verify no data loss occurred during abort process
- **Schedule Impact**: Assess impact on migration timeline and business plans

### Technical Impact Assessment
```bash
# Generate abort impact report
./soviez.sh migration abort-report --migration-id mig-20260802-153000

# Check for any system changes
./soviez.sh system diff --before-migration

# Verify system performance baseline
./soviez.sh system performance-baseline --compare-pre-migration
```

## Prevention and Best Practices

### Pre-Migration Validation
- **Network Testing**: Thoroughly test network connectivity and bandwidth
- **Resource Planning**: Ensure adequate resources on both source and destination
- **Time Planning**: Allow generous time estimates with buffer for unexpected issues
- **Backup Verification**: Ensure recent backups available before starting migration

### Monitoring and Early Detection
- **Set up Alerts**: Configure notifications for transfer issues
- **Monitor Progress**: Actively monitor transfer progress and performance
- **Define Abort Triggers**: Establish clear criteria for when to abort
- **Communication Plan**: Ensure stakeholders aware of abort procedures

### Documentation and Audit
- **Record Decisions**: Document reasons for abort and lessons learned
- **Update Procedures**: Improve migration procedures based on abort experience
- **Share Knowledge**: Communicate learnings to prevent similar issues
- **Plan Recovery**: Develop improved plans for future migration attempts