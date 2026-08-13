# Migration Config and Secret Protocol

## Overview

The configuration and secret migration protocol handles secure transfer of application settings while explicitly excluding sensitive credentials and implementing sanitization procedures for safe migration.

## Configuration Classification

### Transferable Configuration
- **Application Settings**: Non-sensitive system configuration
- **User Preferences**: UI settings and user-specific options
- **Business Logic**: Workflow configurations and business rules
- **Integration Endpoints**: Non-authenticated API endpoints and webhooks
- **UI Customizations**: Theme settings and layout preferences

### Excluded Secrets
- **Database Credentials**: PostgreSQL connection strings and passwords
- **API Keys**: Third-party service authentication keys
- **OAuth Tokens**: Authentication and refresh tokens
- **Encryption Keys**: Data encryption and signing keys
- **SSL Certificates**: Private keys and certificate files
- **Session Secrets**: Application session encryption keys

## Configuration Discovery

### Config File Scanning
```bash
# Identify configuration files
find /opt/odoo -name "*.conf" -o -name "*.cfg" -o -name "*.ini" \
  | grep -v -E "(backup|temp|cache)" > config_files.txt

# Extract environment variables
env | grep -E "^(ODOO|POSTGRES|DB)_" | sort > env_vars.txt

# Database configuration records
psql -c "SELECT name, value FROM ir_config_parameter 
         WHERE name NOT LIKE '%password%' 
         AND name NOT LIKE '%secret%' 
         AND name NOT LIKE '%key%';" > db_config.csv
```

### Configuration Metadata
```python
def analyze_config_file(file_path):
    config = {
        'file_path': file_path,
        'sections': {},
        'secrets_detected': False,
        'sanitization_needed': False
    }
    
    with open(file_path, 'r') as f:
        content = f.read()
        
    # Detect secret patterns
    secret_patterns = [
        r'password\s*=\s*\S+',
        r'api_key\s*=\s*\S+',
        r'secret\s*=\s*\S+',
        r'token\s*=\s*\S+'
    ]
    
    for pattern in secret_patterns:
        if re.search(pattern, content, re.IGNORECASE):
            config['secrets_detected'] = True
            break
    
    return config
```

## Sanitization Process

### Secret Removal
```python
def sanitize_config(config_content):
    sanitized = config_content
    
    # Remove password lines
    sanitized = re.sub(r'^.*password\s*=.*$', '# PASSWORD_REMOVED', 
                      sanitized, flags=re.MULTILINE | re.IGNORECASE)
    
    # Remove API keys
    sanitized = re.sub(r'^.*api_key\s*=.*$', '# API_KEY_REMOVED', 
                      sanitized, flags=re.MULTILINE | re.IGNORECASE)
    
    # Remove secrets
    sanitized = re.sub(r'^.*secret\s*=.*$', '# SECRET_REMOVED', 
                      sanitized, flags=re.MULTILINE | re.IGNORECASE)
    
    # Remove tokens
    sanitized = re.sub(r'^.*token\s*=.*$', '# TOKEN_REMOVED', 
                      sanitized, flags=re.MULTILINE | re.IGNORECASE)
    
    return sanitized
```

### Placeholder Insertion
- **Environment Variables**: Replace secrets with `${ENV_VAR_NAME}` placeholders
- **Configuration Comments**: Add comments indicating required manual setup
- **Template Values**: Insert template values for common configuration patterns
- **Documentation References**: Include links to configuration documentation

## Transfer Protocol

### Config Package Structure
```json
{
  "config_package": {
    "version": "1.0",
    "source_instance": "instance_id",
    "created_at": "2026-08-02T15:30:00Z",
    "files": [
      {
        "path": "/opt/odoo/config/odoo.conf",
        "original_size": 2048,
        "sanitized_size": 1856,
        "secrets_removed": 3,
        "checksum": "sha256_hash"
      }
    ],
    "database_config": [
      {
        "parameter": "web.base.url",
        "value": "https://erp.company.com",
        "sanitized": false
      }
    ],
    "excluded_files": [
      "/opt/odoo/config/secrets.conf",
      "/etc/ssl/private/server.key"
    ]
  }
}
```

### Chunked Transfer
- **Small Chunks**: 64KB chunks for configuration files
- **Atomic Updates**: Complete configuration sets transferred as units
- **Verification**: Checksum validation for sanitized configurations
- **Recovery**: Rollback capability for configuration transfer failures

## Destination Assembly

### Configuration Restoration
```python
def restore_config_package(package_data, destination_path):
    for file_config in package_data['files']:
        dest_file = os.path.join(destination_path, file_config['path'])
        
        # Create directory if needed
        os.makedirs(os.path.dirname(dest_file), exist_ok=True)
        
        # Restore sanitized configuration
        with open(dest_file, 'w') as f:
            f.write(file_config['content'])
        
        # Set appropriate permissions
        os.chmod(dest_file, 0o644)
        
        # Log sanitization actions
        if file_config['secrets_removed'] > 0:
            log_sanitization(dest_file, file_config['secrets_removed'])
```

### Manual Setup Requirements
- **Secret Inventory**: Generate list of secrets requiring manual configuration
- **Setup Instructions**: Provide step-by-step setup guide for excluded secrets
- **Validation Scripts**: Scripts to verify configuration completeness
- **Default Values**: Suggest secure default values where appropriate

## Database Configuration Migration

### Safe Parameter Transfer
```sql
-- Export safe configuration parameters
SELECT name, value 
FROM ir_config_parameter 
WHERE name NOT IN (
  'database.secret',
  'database.uuid',
  'web.session.authenticate.key',
  'auth_oauth.client_secret'
) AND name NOT LIKE '%password%'
  AND name NOT LIKE '%key%'
  AND name NOT LIKE '%secret%'
  AND name NOT LIKE '%token%';
```

### Parameter Sanitization
- **URL Sanitization**: Remove authentication tokens from URLs
- **Path Sanitization**: Update paths for destination environment
- **Domain Updates**: Replace source domain references with placeholders
- **Feature Flags**: Maintain business logic configuration flags

## Security Audit

### Secret Detection Validation
```python
def audit_config_transfer(config_package):
    audit_results = {
        'secrets_found': False,
        'violations': [],
        'recommendations': []
    }
    
    # Scan for accidentally included secrets
    secret_patterns = [
        r'[A-Za-z0-9+/]{32,}={0,2}',  # Base64 encoded secrets
        r'sk_[a-zA-Z0-9]{24,}',       # API key patterns
        r'[0-9a-f]{32,64}'            # Hex encoded secrets
    ]
    
    for file_data in config_package['files']:
        content = file_data['content']
        for pattern in secret_patterns:
            matches = re.findall(pattern, content)
            if matches:
                audit_results['violations'].append({
                    'file': file_data['path'],
                    'pattern': pattern,
                    'matches': len(matches)
                })
                audit_results['secrets_found'] = True
    
    return audit_results
```

### Compliance Verification
- **Data Classification**: Verify no sensitive data in configuration transfers
- **Access Logging**: Complete audit trail of configuration access
- **Encryption Verification**: Ensure mTLS encryption for all config transfers
- **Retention Policy**: Automatic cleanup of configuration transfer artifacts

## Post-Migration Setup

### Secret Regeneration
- **New Passwords**: Generate new secure passwords for destination
- **Fresh API Keys**: Create new API keys for third-party integrations
- **Certificate Generation**: Generate new SSL certificates for destination
- **Session Keys**: Create new session encryption keys

### Validation and Testing
- **Configuration Completeness**: Verify all required settings configured
- **Connectivity Testing**: Test external integrations and services
- **Security Validation**: Verify security settings and access controls
- **Performance Baseline**: Establish performance metrics for new configuration