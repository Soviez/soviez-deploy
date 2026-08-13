# Domain / SSL Phase Boundary — Phase 17 vs 18

## Phase 17 may inspect

- Current Production domain  
- DNS records (read)  
- Current certificate + expiry  
- Destination reachability  
- Candidate migration subdomain **possibility** (planning)  
- Required ports  

## Phase 17 must not

- Change DNS  
- Issue final migration certificate  
- Switch domain  
- Enable maintenance landing  
- Disable source routing  

Those belong to **Phase 18**.

## Reuse

Phase 12 readiness + try-again/abort UX inform Phase 18; Phase 17 only reports domain/SSL readiness flags into the readiness report.
