# Migration Source Freeze Protocol

## Overview

The source freeze protocol implements application-level write freeze during critical migration phases to ensure data consistency while minimizing downtime through coordinated freeze activation, monitoring, and release.

## Freeze Architecture

### Application-Level Freeze
- **Marker File**: `/tmp/soviez_write_freeze.marker` signals freeze state
- **State JSON**: `/tmp/soviez_freeze_state.json` captures application state
- **Process Coordination**: All write operations check freeze marker before proceeding
- **Graceful Degradation**: Read operations continue during freeze period

### Freeze Components
```python
class MigrationFreeze:
    def __init__(self):
        self.marker_file = "/tmp/soviez_write_freeze.marker"
        self.state_file = "/tmp/soviez_freeze_state.json"
        self.freeze_timeout = 1800  # 30 minutes maximum
        
    def activate_freeze(self):
        freeze_state = {
            'activated_at': datetime.utcnow().isoformat(),
            'process_id': os.getpid(),
            'reason': 'migration_transfer',
            'timeout_at': (datetime.utcnow() + 
                         timedelta(seconds=self.freeze_timeout)).isoformat()
        }
        
        # Create marker file atomically
        with open(self.marker_file + '.tmp', 'w') as f:
            f.write(str(os.getpid()))
            f.flush()
            os.fsync(f.fileno())
        
        os.rename(self.marker_file + '.tmp', self.marker_file)
        
        # Save freeze state
        with open(self.state_file, 'w') as f:
            json.dump(freeze_state, f, indent=2)
```

## Freeze Activation Process

### Pre-Freeze Validation
1. **System Health Check**: Verify system resources and stability
2. **Active Connection Count**: Monitor current user connections
3. **Pending Operations**: Check for long-running operations
4. **Backup Verification**: Ensure recent backup availability
5. **Rollback Plan**: Confirm rollback procedures ready

### Freeze Sequence
```bash
# 1. Notify active users (optional warning period)
echo "$(date): Migration starting in 5 minutes - save your work" | \
  tee /opt/odoo/maintenance_notice.txt

# 2. Drain active connections
sleep 300  # 5-minute warning period

# 3. Activate write freeze
python3 -c "
import sys
sys.path.append('/opt/soviez')
from migration.freeze import MigrationFreeze
freeze = MigrationFreeze()
freeze.activate_freeze()
print('Write freeze activated')
"

# 4. Verify freeze activation
if [ -f "/tmp/soviez_write_freeze.marker" ]; then
    echo "$(date): Write freeze active - proceeding with migration"
else
    echo "$(date): ERROR - Write freeze activation failed"
    exit 1
fi
```

## Write Operation Interception

### Database Write Prevention
```python
def check_write_freeze():
    """Check if write operations are frozen"""
    marker_file = "/tmp/soviez_write_freeze.marker"
    
    if os.path.exists(marker_file):
        # Read freeze metadata
        try:
            with open("/tmp/soviez_freeze_state.json", 'r') as f:
                freeze_state = json.load(f)
            
            # Check if freeze has timed out
            timeout_time = datetime.fromisoformat(freeze_state['timeout_at'])
            if datetime.utcnow() > timeout_time:
                # Auto-release expired freeze
                release_freeze()
                return False
            
            return True
        except (FileNotFoundError, json.JSONDecodeError, KeyError):
            # Invalid freeze state - assume not frozen
            return False
    
    return False

# Decorator for write operations
def freeze_aware_write(func):
    def wrapper(*args, **kwargs):
        if check_write_freeze():
            raise WriteOperationFrozenError(
                "Write operations are frozen during migration"
            )
        return func(*args, **kwargs)
    return wrapper
```

### Application Integration Points
- **ORM Operations**: Intercept create, update, delete operations
- **File Uploads**: Block new file uploads during freeze
- **Configuration Changes**: Prevent system configuration modifications
- **User Management**: Block user creation and permission changes

## Freeze Monitoring

### Freeze State Monitoring
```python
def monitor_freeze_state():
    """Monitor freeze state and handle timeout conditions"""
    while True:
        if not os.path.exists("/tmp/soviez_write_freeze.marker"):
            break
        
        try:
            with open("/tmp/soviez_freeze_state.json", 'r') as f:
                freeze_state = json.load(f)
            
            activated_at = datetime.fromisoformat(freeze_state['activated_at'])
            timeout_at = datetime.fromisoformat(freeze_state['timeout_at'])
            current_time = datetime.utcnow()
            
            # Calculate remaining time
            remaining_seconds = (timeout_at - current_time).total_seconds()
            
            if remaining_seconds <= 0:
                log_error(f"Freeze timeout exceeded, auto-releasing")
                release_freeze()
                break
            
            # Log freeze status
            duration = (current_time - activated_at).total_seconds()
            log_info(f"Freeze active for {duration:.0f}s, {remaining_seconds:.0f}s remaining")
            
        except Exception as e:
            log_error(f"Error monitoring freeze state: {e}")
            break
        
        time.sleep(30)  # Check every 30 seconds
```

### Health Monitoring During Freeze
- **Read Operation Performance**: Monitor read query performance
- **System Resources**: Track CPU, memory, disk usage
- **User Experience**: Monitor user session stability
- **Database Connections**: Track connection pool status

## Timeout and Recovery

### Automatic Timeout Handling
```python
def setup_freeze_timeout():
    """Setup automatic freeze release on timeout"""
    def timeout_handler(signum, frame):
        log_error("Freeze timeout reached - automatically releasing freeze")
        release_freeze()
        sys.exit(1)
    
    signal.signal(signal.SIGALRM, timeout_handler)
    signal.alarm(1800)  # 30-minute timeout
```

### Manual Recovery Procedures
```bash
# Emergency freeze release
#!/bin/bash
echo "$(date): Emergency freeze release initiated"

# Remove freeze marker
if [ -f "/tmp/soviez_write_freeze.marker" ]; then
    rm -f "/tmp/soviez_write_freeze.marker"
    echo "$(date): Freeze marker removed"
fi

# Remove freeze state
if [ -f "/tmp/soviez_freeze_state.json" ]; then
    rm -f "/tmp/soviez_freeze_state.json" 
    echo "$(date): Freeze state cleared"
fi

# Restart application services if needed
systemctl restart odoo
echo "$(date): Application services restarted"
```

## Freeze Release Protocol

### Normal Release Sequence
```python
def release_freeze():
    """Release write freeze and restore normal operations"""
    try:
        # Read current freeze state
        if os.path.exists("/tmp/soviez_freeze_state.json"):
            with open("/tmp/soviez_freeze_state.json", 'r') as f:
                freeze_state = json.load(f)
            
            activated_at = datetime.fromisoformat(freeze_state['activated_at'])
            duration = (datetime.utcnow() - activated_at).total_seconds()
            
            log_info(f"Releasing freeze after {duration:.2f} seconds")
        
        # Remove freeze marker atomically
        if os.path.exists("/tmp/soviez_write_freeze.marker"):
            os.remove("/tmp/soviez_write_freeze.marker")
        
        # Clean up freeze state
        if os.path.exists("/tmp/soviez_freeze_state.json"):
            os.remove("/tmp/soviez_freeze_state.json")
        
        # Clear maintenance notice
        if os.path.exists("/opt/odoo/maintenance_notice.txt"):
            os.remove("/opt/odoo/maintenance_notice.txt")
        
        log_info("Write freeze successfully released")
        
    except Exception as e:
        log_error(f"Error releasing freeze: {e}")
        raise
```

### Post-Release Validation
- **Write Operation Test**: Verify write operations resume successfully
- **Database Connectivity**: Confirm database write access restored
- **User Notification**: Notify users that normal operations resumed
- **Performance Baseline**: Verify system performance returns to normal

## Error Handling

### Freeze Activation Failures
- **Resource Constraints**: Handle insufficient system resources
- **Permission Issues**: Resolve file system permission problems
- **Process Conflicts**: Handle competing freeze requests
- **State Corruption**: Recover from corrupted freeze state files

### Freeze Operation Failures
- **Timeout Exceeded**: Automatic release with error logging
- **System Crashes**: Recovery procedures for unexpected system failures
- **Network Issues**: Handle network connectivity problems during freeze
- **Database Locks**: Resolve database locking conflicts

## Integration with Migration Components

### Database Transfer Coordination
- **Pre-Dump Freeze**: Activate freeze before pg_dump execution
- **Dump Duration**: Maintain freeze throughout dump process
- **Post-Dump Release**: Release freeze after successful dump completion
- **Failure Rollback**: Release freeze immediately on dump failures

### Filestore Transfer Coordination
- **Final Delta Freeze**: Activate freeze for final filestore delta transfer
- **Change Detection**: Monitor for file changes during freeze
- **Transfer Validation**: Verify no changes occurred during transfer
- **Atomic Release**: Release freeze after transfer validation

## Testing and Validation

### Freeze Functionality Tests
```python
def test_freeze_activation():
    """Test write freeze activation and validation"""
    freeze = MigrationFreeze()
    
    # Test freeze activation
    freeze.activate_freeze()
    assert os.path.exists("/tmp/soviez_write_freeze.marker")
    assert check_write_freeze() == True
    
    # Test write operation blocking
    with pytest.raises(WriteOperationFrozenError):
        perform_test_write_operation()
    
    # Test freeze release
    freeze.release_freeze()
    assert not os.path.exists("/tmp/soviez_write_freeze.marker")
    assert check_write_freeze() == False
```

### Performance Impact Testing
- **Baseline Performance**: Measure normal operation performance
- **Freeze Impact**: Measure read performance during freeze
- **Recovery Time**: Measure time to restore normal operations
- **User Experience**: Validate acceptable user experience during freeze