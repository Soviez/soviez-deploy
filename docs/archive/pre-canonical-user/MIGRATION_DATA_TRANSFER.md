# Migration Data Transfer Guide

## Overview

The Soviez migration system enables secure, resumable transfer of your complete ERP system to a new server with minimal downtime. This guide explains how data transfer works and what to expect during the migration process.

## What Gets Transferred

### Database
- **All Business Data**: Complete PostgreSQL database with all records
- **User Accounts**: User profiles, permissions, and preferences  
- **System Configuration**: Application settings and customizations
- **Transaction History**: Complete audit trail and business records

### File Storage
- **Document Attachments**: All uploaded files and documents
- **User Images**: Profile pictures and uploaded media
- **Report Templates**: Custom report layouts and formats
- **Static Assets**: Custom themes and UI resources

### Add-on Modules
- **Custom Modules**: Your organization-specific developments
- **Third-Party Modules**: Marketplace and external modules
- **Module Data**: Module-specific data and configurations
- **Dependencies**: Required supporting modules

### System Configuration
- **Application Settings**: Non-sensitive system preferences
- **UI Customizations**: Menu layouts and interface modifications
- **Workflow Configurations**: Business process definitions
- **Integration Settings**: Non-authenticated external connections

## What Does NOT Get Transferred

### Security-Sensitive Information
- **Database Passwords**: PostgreSQL and admin credentials
- **API Keys**: Third-party service authentication keys
- **SSL Certificates**: Private keys and certificate files
- **Session Secrets**: Application session encryption keys
- **OAuth Tokens**: Authentication and refresh tokens

### Temporary Data
- **Cache Files**: System cache and temporary processing files
- **Log Files**: Application and system logs
- **Backup Files**: Existing backup archives
- **Session Data**: Active user sessions

> **Important**: You'll need to reconfigure passwords, API keys, and certificates on the destination system after migration.

## Transfer Process Overview

### Phase 1: Pre-Migration Sync
The migration begins with a **pre-sync** phase while your system remains fully operational:

1. **File Pre-Transfer**: Large files and attachments transfer first
2. **Add-on Pre-Transfer**: Custom modules and their data transfer
3. **Multiple Passes**: Process repeats to minimize final transfer time
4. **No Downtime**: System remains available during pre-sync

### Phase 2: Final Sync (Brief Downtime)
A short maintenance window completes the migration:

1. **Write Freeze**: System enters read-only mode (typically 5-15 minutes)
2. **Database Transfer**: Complete database dump and transfer
3. **Final File Sync**: Transfer any files changed during pre-sync
4. **Configuration Transfer**: System settings and preferences

### Phase 3: Destination Validation
Your data is validated on the new server:

1. **Database Restore**: Data restored and integrity verified
2. **File Assembly**: Files reconstructed and validated
3. **System Testing**: Basic functionality tested
4. **License Validation**: Temporary license activated for testing

## Transfer Security

### Encryption and Privacy
- **End-to-End Encryption**: All data encrypted during transfer using mTLS
- **Direct Transfer**: No intermediate storage on third-party systems
- **Certificate Authentication**: Mutual authentication prevents interception
- **No SaaS Relay**: Direct source-to-destination transfer only

### Data Sanitization
- **Secret Removal**: Passwords and keys automatically excluded
- **Staging Isolation**: Destination validation in isolated environment
- **Temporary Licenses**: Short-term licenses for validation only
- **Automatic Cleanup**: Staging environment cleaned after validation

## Monitoring Transfer Progress

### Progress Indicators
```text
Migration Progress: Phase 2 - Database Transfer
├── Database: [████████████░░░░] 75% (2.1GB/2.8GB)
├── Filestore: [████████████████] 100% (450MB/450MB) 
├── Addons: [████████████████] 100% (12MB/12MB)
└── Staging: [░░░░░░░░░░░░░░░░] 0% (Not Started)

Estimated Time Remaining: 8 minutes
Current Phase: Database transfer in progress
Network Speed: 15.2 MB/s average
```

### Status Messages
- **"Pre-sync in progress"**: Files transferring while system operational  
- **"Write freeze active"**: Brief maintenance window started
- **"Database transfer"**: PostgreSQL dump and transfer in progress
- **"Staging validation"**: Testing data integrity on destination
- **"Transfer complete"**: All data successfully transferred and validated

## Resumable Transfers

### Automatic Resume
If the transfer is interrupted, it automatically resumes from where it left off:

- **Network Issues**: Automatic reconnection and resume
- **Server Restarts**: Resume from last completed chunk
- **Power Outages**: State preserved for recovery
- **Manual Cancellation**: Clean abort with full rollback

### Manual Resume
If needed, you can manually resume a paused transfer:

```bash
# Check transfer status
./soviez.sh migration status

# Resume paused transfer  
./soviez.sh migration resume

# Check detailed progress
./soviez.sh migration progress --detailed
```

## Network and Performance

### Bandwidth Requirements
- **Minimum**: 1 Mbps for small systems (under 1GB)
- **Recommended**: 10 Mbps for typical systems (1-10GB)
- **Large Systems**: 100 Mbps or higher for systems over 50GB

### Transfer Time Estimates

| System Size | Network Speed | Estimated Time |
|-------------|---------------|----------------|
| Small (1GB) | 10 Mbps | 15-30 minutes |
| Medium (5GB) | 10 Mbps | 1-2 hours |
| Large (20GB) | 10 Mbps | 4-6 hours |
| Large (20GB) | 100 Mbps | 30-45 minutes |

### Performance Optimization
- **Pre-sync Strategy**: Multiple pre-sync passes reduce final downtime
- **Compression**: Automatic compression for text-heavy data
- **Parallel Transfers**: Multiple concurrent streams when possible
- **Chunked Transfer**: Resumable 1-10MB chunks for reliability

## Troubleshooting Transfer Issues

### Common Issues

**Slow Transfer Speed**
- Check network bandwidth and latency
- Verify no other heavy network usage
- Consider scheduling during off-peak hours

**Transfer Failures**
- Review network connectivity between servers
- Check available disk space on destination
- Verify firewall and port configuration

**Authentication Errors**
- Confirm migration certificates are valid
- Check system time synchronization
- Verify migration token hasn't expired

### Getting Help
If you experience transfer issues:

1. **Check Status**: Use `./soviez.sh migration status` for detailed information
2. **Review Logs**: Check transfer logs for specific error messages  
3. **Network Test**: Verify connectivity between source and destination
4. **Support Contact**: Contact support with migration ID and error details

## Post-Transfer Next Steps

### Required Configuration
After successful data transfer, you'll need to configure:

- **Database Credentials**: Set new PostgreSQL passwords
- **SSL Certificates**: Install SSL certificates for HTTPS access
- **API Keys**: Reconfigure third-party service credentials
- **Email Settings**: Configure SMTP server settings
- **Domain Setup**: Update DNS and domain configuration

### Validation Checklist
- [ ] Test user login functionality
- [ ] Verify critical business data present
- [ ] Test file upload/download functionality
- [ ] Confirm custom modules working
- [ ] Validate integration connections
- [ ] Test backup and restore procedures

### Cutover Planning
The data transfer creates a validated staging environment. Production cutover is a separate process that involves:

- DNS updates to point to new server
- SSL certificate installation and validation
- Final system configuration and testing
- User notification and training if needed