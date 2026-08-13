# Test Plan — Phase 17 (implementation-ready; not executed)

## Discovery

- Exact Production PASS  
- Wrong target / Stage denied / ambiguous  
- Identity mismatch  
- Docker / PostgreSQL / filestore sizing / addon inventory / Stage inventory  
- Secret exclusion (static + runtime)  
- Active-operation conflict  
- Source remains running  

## Destination bootstrap

- Supported / unsupported OS; architecture  
- Disk / inodes / RAM / CPU gates  
- Docker / Compose presence  
- Signed installer; wrong signature; wrong digest  
- `--init` neutral; temporary identity; **no** Production activation  
- Reboot recovery; abort  

## Pairing

- Valid source/destination  
- Wrong source / destination / License  
- Expired challenge; replay; signature tamper  
- Fingerprint confirmation; revocation  
- Reboot; abort  

## Readiness

- Full PASS / WARNING / BLOCKED  
- Capacity / connectivity / addon / missing image  
- Backup prerequisite policies  
- Migration Token eligible / missing; **assert not consumed**  
- Report signature / expiry  

## Security

- MITM / host-key substitution / unsigned installer  
- Cross-tenant pair  
- Secret leakage / command injection  
- Forged / stale report  
- Premature activation / token burn  
- Payload-transfer static gate  
- `MIGRATION_DATA_TRANSFER_NOT_AUTHORIZED`  

## Integration (disposable only)

- Disposable source Production + clean destination VM  
- Real signed installer + bootstrap + pairing  
- Synthetic connectivity test  
- Readiness report  
- Abort  
- Host reboot mid discovery/bootstrap/pairing  
- Assert: source healthy; no DB/filestore transfer; no DNS; no token consumption; dest not activated  

## Out of scope for Phase 17 suites

Streaming, DNS cutover, token burn, dest Production activate, source purge.
