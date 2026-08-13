# Archive versus Purge Model

## ARCHIVE (Phase 22)

Archive is:

- reversible
- exact-source scoped
- verifiable
- encrypted
- checksummed
- operation-bound
- retained per policy
- recoverable through documented procedures
- non-public
- non-running or restricted
- auditable
- incapable of generating business side effects

Archive may include: verified DB dump, verified filestore archive, sanitized config, addon manifest, image digest, environment manifest, License-state receipt, DNS snapshot, certificate **public** metadata, encrypted local secrets package (if explicitly approved), infrastructure inventory, restore instructions, checksum manifest.

## PURGE (NOT Phase 22)

Purge means irreversible destruction of one or more of:

- source database / filestore / backup / volume / disk / snapshot / host
- source certificate private key
- source infrastructure credentials
- archive copy itself

Purge requires:

- explicit **separate** owner authorization
- exact object targeting
- typed confirmation
- fresh safety preflight
- minimum required archive copies
- verified restore evidence
- retention-policy eligibility
- legal/compliance confirmation where applicable
- no automatic inclusion in archive
- immutable destruction receipt

## Boundary

```text
Phase 22 archives and prepares retirement.
Purge remains forbidden.
```

Archive success ≠ permission to purge.  
`purge_authorized=false` and `deletion_performed=false` on every Phase 22 archive manifest.
