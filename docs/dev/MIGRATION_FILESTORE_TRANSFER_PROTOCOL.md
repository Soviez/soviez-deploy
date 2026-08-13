# Migration Filestore Transfer Protocol

## Overview

The filestore transfer protocol implements multi-pass synchronization of file attachments and user uploads with delta detection, resumable transfers, and minimal downtime through pre-sync optimization.

## Multi-Pass Transfer Strategy

### Phase 1: Initial Pre-Sync
- **Full Discovery**: Enumerate all files in source filestore directories
- **Metadata Collection**: File size, modification time, checksum calculation
- **Transfer Planning**: Prioritize large files and create transfer manifest
- **Baseline Transfer**: Transfer majority of files while system remains active

### Phase 2: Delta Sync (Repeatable)
- **Change Detection**: Compare checksums and modification times
- **Delta Identification**: Identify new, modified, and deleted files
- **Incremental Transfer**: Transfer only changed files
- **Progress Optimization**: Reduce final sync time through repeated delta passes

### Phase 3: Final Delta (Write Freeze)
- **Freeze Activation**: Coordinate with write freeze for consistency
- **Final Scan**: Detect any last-minute file changes
- **Quick Transfer**: Transfer final delta set (minimized through pre-sync)
- **Validation**: Verify complete filestore synchronization

## File Discovery and Enumeration

### Source Scanning
```bash
find /opt/odoo/data/filestore -type f -exec stat -c '%n|%s|%Y|' {} \; \
  | while IFS='|' read -r file size mtime; do
    checksum=$(sha256sum "$file" | cut -d' ' -f1)
    echo "$file|$size|$mtime|$checksum"
  done > filestore_manifest.txt
```

### Exclusion Rules
- Skip temporary files (`*.tmp`, `*.lock`)
- Exclude backup files (`*.bak`, `*~`)
- Ignore system files (`.DS_Store`, `Thumbs.db`)
- Skip empty directories and symlinks

## Chunked File Transfer

### File Chunking Strategy
- **Small Files** (<1MB): Transfer as single chunk
- **Medium Files** (1-10MB): 1MB chunks for resumability
- **Large Files** (>10MB): 5MB chunks for efficiency
- **Archive Files**: Special handling for compressed formats

### Chunk Transmission Protocol
1. **File Header**: Send file metadata (path, size, permissions, timestamps)
2. **Chunk Stream**: Sequential chunk transmission with checksums
3. **Chunk Verification**: Destination validates each chunk before acknowledgment
4. **File Assembly**: Reconstruct complete file from received chunks
5. **File Validation**: Verify final file checksum and metadata

## Delta Detection

### Change Identification
```python
def detect_changes(source_manifest, destination_manifest):
    changes = {
        'new': [],      # Files not in destination
        'modified': [], # Files with different checksums
        'deleted': []   # Files not in source
    }
    
    for file_path, source_meta in source_manifest.items():
        if file_path not in destination_manifest:
            changes['new'].append(file_path)
        elif source_meta['checksum'] != destination_manifest[file_path]['checksum']:
            changes['modified'].append(file_path)
    
    for file_path in destination_manifest:
        if file_path not in source_manifest:
            changes['deleted'].append(file_path)
    
    return changes
```

### Optimization Strategies
- **Timestamp Heuristics**: Skip checksum calculation if timestamps match
- **Size Comparison**: Quick size mismatch detection before checksum
- **Parallel Processing**: Concurrent file scanning on multi-core systems
- **Incremental Updates**: Maintain change logs between sync passes

## Directory Structure Preservation

### Path Mapping
- Maintain exact directory structure from source to destination
- Create intermediate directories as needed during file transfer
- Preserve file permissions and ownership where possible
- Handle special characters and unicode in file paths

### Symlink Handling
- Document symlinks in transfer manifest
- Transfer symlink targets as regular files
- Recreate symlinks on destination after file transfer completion
- Validate symlink integrity post-transfer

## Error Recovery

### File Transfer Failures
- **Permission Denied**: Log error and continue with other files
- **Disk Full**: Pause transfer and notify administrator
- **Corruption Detection**: Retransmit corrupted files automatically
- **Network Timeout**: Resume from last completed chunk

### Consistency Validation
- **Checksum Verification**: Compare source and destination file checksums
- **Size Validation**: Verify transferred file sizes match source
- **Timestamp Preservation**: Maintain file modification times where possible
- **Missing File Detection**: Identify and report any missing files post-transfer

## Performance Optimization

### Parallel Transfer
- **Concurrent Files**: Transfer multiple files simultaneously
- **Thread Pool**: Configurable thread count based on system resources
- **Bandwidth Throttling**: Limit transfer rate to prevent network saturation
- **Priority Queue**: Prioritize small files for quick completion

### Compression Optimization
- **Archive Detection**: Identify pre-compressed files to avoid double compression
- **Text Files**: Apply compression to text-based files for bandwidth efficiency
- **Binary Files**: Skip compression for images and media files
- **Compression Ratio**: Monitor compression effectiveness and adjust strategy