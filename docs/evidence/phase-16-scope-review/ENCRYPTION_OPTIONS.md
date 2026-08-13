# Encryption Options — Phase 16 (Proposed)

## Principles

- Keys **never** sent to Soviez SaaS.  
- Malicious Root can always read host memory/disk — document honestly; encryption protects remotes, stolen disks, and casual local access.  
- Remote backups: encryption **mandatory**.  
- Local backups: **strongly recommended / default-on** with explicit owner opt-out (**OD-01**).

## Candidate constructions

| Option | Pros | Cons |
|--------|------|------|
| **age** | Simple recipient model; modern defaults; easy key files | Ecosystem/tooling must be pinned in installer |
| **AES-256-GCM envelope** | Familiar; DEK+KEK pattern; streaming AEAD | Key wrap/policy complexity; nonce discipline |
| Plain tar + OS disk encryption only | Simple | Fails remote/stolen-disk threat; insufficient alone for remote |

## Recommendation (for owner decision)

Present as **OWNER DECISION** between:

1. **age** for archive encryption, or  
2. **AES-256-GCM envelope** (random DEK per backup, wrapped by owner KEK)

Either is acceptable if:

- Streaming encrypt (no full archive in RAM)  
- Manifest clears vs ciphertext separation documented  
- Key material never in argv/logs  
- Wrong-key restore fails closed  

## Policy matrix (proposed defaults pending OD)

| Destination | Encryption |
|-------------|------------|
| Remote S3/SFTP | **Mandatory** |
| Local | Default **on**; owner may opt out with recorded acknowledgment |
| Export path | Follow stricter of source policy / explicit flag |

## Key custody

| Topic | Proposal |
|-------|----------|
| Storage | Host-local key store; permissions 600/700 |
| SaaS | No key upload; OD-15 if any encrypted admin assist ever considered |
| Rotation | Documented procedure; old backups remain decryptable with old keys |
| Backup of keys | Owner responsibility; installer warns |

## Non-goals

- Soviez custodial KMS  
- Transparent encryption that hides Root compromise  
- Encrypting away License Guard or entitlement checks
