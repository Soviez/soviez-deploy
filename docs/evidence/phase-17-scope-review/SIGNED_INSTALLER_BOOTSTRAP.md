# Signed Installer Bootstrap — Phase 17

## Requirements

- Signed installer/package only  
- Immutable version or digest — **no** mutable `latest`  
- Signature verification **before** execution  
- Checksum + architecture compatibility  
- Trusted public key pinning  
- Exact requested version  
- No permanent registry credentials left on host  
- No secret embedded in installer artifact  
- Audit record of verify + version/digest  
- Offline bootstrap package option  

## Connected flow

1. Owner requests exact version/digest (or pin from source discovery).  
2. Device-authorized or owner-authenticated session obtains signed release/installer manifest via Registry/SaaS pull APIs (Phase 7 patterns).  
3. Verify Ed25519 (or project standard) signature + checksum.  
4. Architecture gate.  
5. Install to controlled path; refuse unsigned overwrite.  
6. Audit: version, digest, fingerprint, timestamp, op ID.  

## Offline flow

1. Owner imports offline signed bootstrap package (pattern: Stage/update offline).  
2. Verify signature against pinned public keys on media.  
3. Same architecture/checksum gates.  
4. No call home required to **execute** verified package; eligibility metadata may remain local.  
5. Optional later connected ack — **no** business payload.

## Explicit bans

- Unsigned self-update (legacy deploy path)  
- Trust-on-first-use without owner confirmation of fingerprints  
- Storing long-lived registry passwords in cleartext  

## Failure codes

`MIGRATION_INSTALLER_SIGNATURE_INVALID`, `MIGRATION_INSTALLER_DIGEST_MISMATCH`, `MIGRATION_BOOTSTRAP_FAILED`.
