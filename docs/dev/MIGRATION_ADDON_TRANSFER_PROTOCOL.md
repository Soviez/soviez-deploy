# Migration Addon Transfer Protocol

## Overview

The addon transfer protocol manages secure migration of custom modules, third-party addons, and their associated data while maintaining version compatibility and configuration integrity.

## Addon Discovery and Classification

### Addon Enumeration
```bash
# Discover installed addons
find /opt/odoo/addons -maxdepth 1 -type d -name "*" \
  | grep -v "__pycache__" | sort > addon_directories.txt

# Extract addon metadata
for addon_dir in $(cat addon_directories.txt); do
  if [ -f "$addon_dir/__manifest__.py" ]; then
    python3 -c "
import ast
with open('$addon_dir/__manifest__.py') as f:
    manifest = ast.literal_eval(f.read())
    print('$addon_dir|' + manifest.get('name', '') + '|' + manifest.get('version', ''))
"
  fi
done > addon_manifest.txt
```

### Addon Classification
- **Core Modules**: Standard Odoo modules (migrate references only)
- **Custom Modules**: Organization-specific development (full transfer)
- **Third-Party**: External marketplace modules (validate compatibility)
- **Modified Core**: Core modules with local modifications (special handling)

## Transfer Packaging

### Addon Archive Creation
```python
def create_addon_package(addon_path, output_dir):
    package = {
        'metadata': extract_manifest(addon_path),
        'files': [],
        'data': extract_addon_data(addon_path),
        'dependencies': resolve_dependencies(addon_path)
    }
    
    # Package addon files
    for root, dirs, files in os.walk(addon_path):
        for file in files:
            if file.endswith(('.py', '.xml', '.csv', '.po', '.js', '.css')):
                file_path = os.path.join(root, file)
                package['files'].append({
                    'path': file_path,
                    'size': os.path.getsize(file_path),
                    'checksum': calculate_checksum(file_path)
                })
    
    return package
```

### Data Extraction
- **Database Records**: Export addon-specific data records
- **Configuration**: Module settings and parameters
- **Translations**: Language files and custom translations
- **Assets**: Static files, images, and resources

## Chunked Transfer Process

### Package Transmission
1. **Manifest Transfer**: Send addon metadata and file listing
2. **File Chunks**: Transfer addon files in 256KB chunks
3. **Data Transfer**: Migrate database records as separate component
4. **Dependency Resolution**: Validate and transfer required dependencies
5. **Integrity Check**: Verify complete addon package integrity

### Chunk Structure
```json
{
  "chunk_type": "addon_file|addon_data|addon_manifest",
  "addon_name": "custom_module_name",
  "chunk_sequence": 1,
  "total_chunks": 15,
  "payload": "base64_encoded_content",
  "checksum": "sha256_hash"
}
```

## Dependency Management

### Dependency Resolution
- **Direct Dependencies**: Modules listed in `__manifest__.py`
- **Indirect Dependencies**: Dependencies of dependencies
- **Version Compatibility**: Check version constraints and conflicts
- **Missing Modules**: Identify and report missing dependencies

### Transfer Order
1. **Core Dependencies**: Transfer base modules first
2. **Third-Party Libraries**: External dependencies and libraries
3. **Custom Base**: Organization-specific base modules
4. **Application Modules**: Business logic and application-specific modules
5. **Customizations**: UI customizations and modifications

## Destination Integration

### Addon Installation
```python
def install_addon_package(package_data, destination_path):
    addon_name = package_data['metadata']['name']
    addon_path = os.path.join(destination_path, addon_name)
    
    # Create addon directory
    os.makedirs(addon_path, exist_ok=True)
    
    # Extract files
    for file_data in package_data['files']:
        restore_file(file_data, addon_path)
    
    # Validate structure
    validate_addon_structure(addon_path)
    
    # Register addon
    register_addon_for_installation(addon_name)
```

### Configuration Migration
- **Module Settings**: Transfer addon-specific configuration
- **User Permissions**: Migrate access rights and security rules
- **Menu Items**: Custom menu entries and navigation
- **Report Templates**: Custom report layouts and templates

## Version Compatibility

### Compatibility Checking
```python
def check_addon_compatibility(source_addon, destination_version):
    compatibility = {
        'compatible': True,
        'warnings': [],
        'blockers': []
    }
    
    # Check Odoo version compatibility
    source_version = source_addon['metadata']['version']
    if not is_version_compatible(source_version, destination_version):
        compatibility['blockers'].append('Version incompatibility')
    
    # Check API changes
    deprecated_apis = check_deprecated_apis(source_addon['files'])
    if deprecated_apis:
        compatibility['warnings'].extend(deprecated_apis)
    
    return compatibility
```

### Migration Strategies
- **Direct Transfer**: Compatible modules transfer without modification
- **API Updates**: Automatic updates for deprecated API usage
- **Manual Review**: Flag modules requiring manual intervention
- **Version Pinning**: Maintain specific version requirements

## Error Handling and Recovery

### Transfer Failures
- **Corrupted Chunks**: Automatic retransmission with integrity verification
- **Missing Dependencies**: Dependency resolution and notification
- **Permission Issues**: Adjust file permissions and ownership
- **Disk Space**: Monitor space requirements and fail gracefully

### Installation Failures
- **Module Conflicts**: Detect and resolve naming conflicts
- **Database Errors**: Handle database schema migration failures
- **Asset Conflicts**: Resolve static file and asset conflicts
- **Configuration Errors**: Validate and repair configuration inconsistencies

## Security Considerations

### Code Review
- **Static Analysis**: Scan custom modules for security vulnerabilities
- **Dependency Audit**: Verify third-party module security
- **Access Control**: Validate permission configurations
- **Data Sanitization**: Clean sensitive data from addon configurations

### Transfer Security
- **Encryption**: mTLS encryption for all addon payload transfers
- **Integrity Verification**: Checksums and digital signatures
- **Access Restrictions**: Limit access to addon transfer processes
- **Audit Logging**: Complete audit trail for addon migration activities