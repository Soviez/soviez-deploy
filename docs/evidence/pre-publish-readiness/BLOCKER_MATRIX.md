# BLOCKER_MATRIX

## Counts

| Class | Count |
|-------|------:|
| BLOCKS_PUBLISH | 3 (PP-01 remote, PP-02 gitignore, PP-03 root secrets exclusion) |
| BLOCKS_MAIN_MERGE | 1 process (PP-04 scoped ERP commit) — closable by discipline |
| BLOCKS_LIVE_SIMULATION | 3 (PP-10, PP-11, PP-12) |
| BLOCKS_PRODUCTION_RELEASE | Release auth + off-host policy + visual acceptance (commercial) |
| OWNER_DECISION | 6+ |
| NON_BLOCKING | 2 |
| RESOLVED | Artifact hash, wizard parity, docs validate, secret_scan PASS, contracts |

## Detail

| ID | Severity | Close action |
|----|----------|--------------|
| PP-01 | BLOCKS_PUBLISH | Owner creates/links GitHub remote for soviez-sh |
| PP-02 | BLOCKS_PUBLISH | Add `.gitignore` (no runtime change) |
| PP-03 | BLOCKS_PUBLISH | Ensure secrets never staged; delete/move out of tree optional later |
| PP-04 | BLOCKS_MAIN_MERGE | Commit only `soviez.sh` in ERP |
| PP-10..12 | BLOCKS_LIVE_SIMULATION | Provision sandbox SaaS, VPS, registry, test license/device |

**Blocking item count (publish+merge hygiene):** 4  
**Live-sim blockers:** 3  
**Non-blocking warnings:** 2  
**Production-release-only:** off-host policy, visual acceptance, commercial release auth
