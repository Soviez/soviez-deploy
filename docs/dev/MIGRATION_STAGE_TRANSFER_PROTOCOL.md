# Migration Stage Transfer Protocol

## Overview

The stage transfer protocol manages the complete migration of stage environments including their isolated runtime configuration, data, and validation processes while maintaining strict isolation from production systems.

## Stage Identification and Classification

### Stage Environment Discovery
```bash
# Enumerate existing stages
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" \
  | grep "soviez-stage-" | sort > active_stages.txt

# Extract stage metadata
for stage_name in $(docker ps --format "{{.Names}}" | grep "soviez-stage-"); do
  stage_id=$(echo $stage_name | cut -d'-' -f3)
  echo "$stage_id|$(docker inspect $stage_name --format '{{.Config.Env}}')" >> stage_metadata.txt
done
```

### Stage Classification
- **Development Stages**: Developer-specific environments for testing
- **QA Stages**: Quality assurance and testing environments
- **Demo Stages**: Customer demonstration and training environments
- **Staging**: Pre-production validation environments

## Stage Data Extraction

### Runtime Configuration
```python
def extract_stage_config(stage_id):
    config = {
        'stage_id': stage_id,
        'container_config': {},
        'environment_vars': {},
        'volume_mounts': [],
        'network_config': {},
        'resource_limits': {}
    }
    
    # Extract container configuration
    container_info = docker_client.containers.get(f'soviez-stage-{stage_id}')
    config['container_config'] = container_info.attrs['Config']
    config['environment_vars'] = dict(env.split('=', 1) for env in container_info.attrs['Config']['Env'])
    
    # Extract volume mounts
    for mount in container_info.attrs['Mounts']:
        if mount['Type'] == 'bind':
            config['volume_mounts'].append({
                'source': mount['Source'],
                'destination': mount['Destination'],
                'read_only': mount.get('RW', True) == False
            })
    
    return config
```

### Stage Database Isolation
- **Separate Database**: Each stage maintains isolated database
- **Data Subset**: Stages may contain subset of production data
- **Test Data**: Synthetic or anonymized test datasets
- **Schema Variations**: Development schema changes and experiments

### Filestore Isolation
- **Stage-Specific Files**: Isolated file storage per stage
- **Test Assets**: Development and testing file uploads
- **Demo Content**: Demonstration-specific files and media
- **Backup Exclusion**: Stage files excluded from production backups

## Transfer Packaging

### Stage Package Structure
```json
{
  "stage_package": {
    "stage_id": "dev-user123",
    "stage_type": "development",
    "created_at": "2026-08-02T15:30:00Z",
    "components": {
      "database": {
        "name": "soviez_stage_dev_user123",
        "size_mb": 45,
        "table_count": 120,
        "record_count": 15000
      },
      "filestore": {
        "path": "/opt/odoo/stages/dev-user123/filestore",
        "file_count": 89,
        "total_size_mb": 12
      },
      "config": {
        "environment_vars": {...},
        "volume_mounts": [...],
        "resource_limits": {...}
      }
    },
    "dependencies": {
      "base_image": "soviez:0.19.0-phase19",
      "custom_addons": ["dev_tools", "test_module"],
      "external_services": []
    }
  }
}
```

## Chunked Transfer Process

### Database Transfer
- **Stage Database Dump**: pg_dump with stage-specific exclusions
- **Anonymization**: Remove or anonymize sensitive data during dump
- **Size Optimization**: Exclude unnecessary test data and logs
- **Compression**: High compression for stage database transfers

### Filestore Transfer
- **Selective Transfer**: Only transfer relevant stage files
- **Test Asset Handling**: Package test-specific assets separately
- **Delta Optimization**: Skip common files already in base system
- **Permission Preservation**: Maintain stage-specific file permissions

### Configuration Transfer
- **Environment Isolation**: Sanitize and adapt environment variables
- **Port Mapping**: Adjust port configurations for destination
- **Resource Scaling**: Adapt resource limits for destination environment
- **Network Isolation**: Configure stage-specific network isolation

## Destination Reconstruction

### Stage Environment Setup
```python
def reconstruct_stage(stage_package, destination_host):
    stage_id = stage_package['stage_id']
    
    # Create stage database
    create_stage_database(stage_id, stage_package['components']['database'])
    
    # Setup stage filestore
    setup_stage_filestore(stage_id, stage_package['components']['filestore'])
    
    # Configure stage container
    container_config = adapt_stage_config(
        stage_package['components']['config'],
        destination_host
    )
    
    # Launch stage container
    launch_stage_container(stage_id, container_config)
    
    # Validate stage functionality
    validate_stage_deployment(stage_id)
```

### Configuration Adaptation
- **Host-Specific Paths**: Update file paths for destination environment
- **Network Configuration**: Adapt networking for destination infrastructure
- **Resource Allocation**: Adjust CPU/memory limits based on destination capacity
- **External Dependencies**: Update external service connections

## Validation and Testing

### Stage Functionality Validation
```python
def validate_stage_deployment(stage_id):
    validation_results = {
        'database_connectivity': False,
        'filestore_access': False,
        'web_interface': False,
        'addon_loading': False,
        'overall_health': False
    }
    
    try:
        # Test database connection
        db_connection = test_stage_database(stage_id)
        validation_results['database_connectivity'] = db_connection
        
        # Test filestore access
        filestore_access = test_stage_filestore(stage_id)
        validation_results['filestore_access'] = filestore_access
        
        # Test web interface
        web_response = test_stage_web_interface(stage_id)
        validation_results['web_interface'] = web_response
        
        # Test addon loading
        addon_status = test_stage_addons(stage_id)
        validation_results['addon_loading'] = addon_status
        
        # Overall health check
        validation_results['overall_health'] = all([
            validation_results['database_connectivity'],
            validation_results['filestore_access'],
            validation_results['web_interface'],
            validation_results['addon_loading']
        ])
        
    except Exception as e:
        log_validation_error(stage_id, str(e))
    
    return validation_results
```

### Performance Baseline
- **Response Time**: Measure stage response times post-migration
- **Resource Usage**: Monitor CPU and memory consumption
- **Database Performance**: Validate database query performance
- **Concurrent Users**: Test multi-user capacity

## Error Handling and Recovery

### Transfer Failures
- **Partial Stage Recovery**: Rollback incomplete stage transfers
- **Dependency Resolution**: Handle missing dependencies gracefully
- **Resource Conflicts**: Resolve port and resource allocation conflicts
- **Data Corruption**: Detect and recover from corrupted stage data

### Validation Failures
- **Component Isolation**: Identify specific failing components
- **Dependency Tracking**: Resolve missing or incompatible dependencies
- **Configuration Repair**: Auto-repair common configuration issues
- **Manual Intervention**: Flag complex issues for manual resolution

## Security and Isolation

### Stage Security Model
- **Network Isolation**: Strict network isolation between stages and production
- **Data Sanitization**: Remove or anonymize sensitive data in stages
- **Access Control**: Stage-specific user access and permissions
- **Resource Limits**: Prevent stages from consuming excessive resources

### Multi-Tenant Isolation
- **Container Isolation**: Docker-based isolation for stage environments
- **Database Separation**: Separate databases for each stage
- **Filestore Segregation**: Isolated file storage per stage
- **Network Segmentation**: Stage-specific network segments

## Lifecycle Management

### Stage Retention
- **Automatic Cleanup**: Remove inactive stages after retention period
- **Usage Tracking**: Monitor stage usage and activity
- **Resource Optimization**: Optimize resource allocation based on usage
- **Backup Exclusion**: Exclude temporary stages from backup processes

### Stage Promotion
- **Development to QA**: Promote successful development stages
- **QA to Staging**: Move validated changes to staging
- **Staging to Production**: Final validation before production deployment
- **Change Tracking**: Maintain audit trail of stage promotions