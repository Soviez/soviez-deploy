# Corrected Scope — Phase 17

## Title assessment

| Wording | Assessment |
|---------|------------|
| Plan stub: “Migration discovery and destination bootstrap” | Incomplete — omits trust pairing and readiness certification |
| **Corrected: Phase 17 — Migration Discovery, Trust Pairing, and Destination Bootstrap** | **More accurate** — matches binding outcome (discovery + bootstrap + trusted pair + readiness) without implying transfer |

**Decision recorded:** Prefer corrected title in PROJECT_STATE / plan notes. Do not silently rename without this note.

## Corrected objective

Prepare a Soviez-to-Soviez migration **safely** by discovering exact source state, bootstrapping a destination with verified signed installer and temporary identity, establishing owner-confirmed trust pairing, and producing a signed readiness report — **without** transferring business payloads, changing DNS, switching traffic, burning a Migration Token, activating destination Production, or disrupting the source.

## Inclusions

- Source discovery (exact Production)  
- Destination host preflight + bootstrap + `--init` readiness  
- Signed installer verification (connected + offline)  
- Exact identity binding + trust pairing  
- Migration-pair object  
- Non-sensitive compatibility + capacity + connectivity assessment  
- Readiness report  
- Dry-run planning (estimates only)  
- Abort behavior + reboot recovery  
- Operation-engine integration  
- Documentation and tests (when implementation authorized)  
- Migration Token **eligibility** display only  
- Stage inventory (unselected)  
- Domain/SSL **inspection** only  

## Exclusions (Phases 18–22)

- Source maintenance mode / destination maintenance landing  
- DNS changes / DNS challenge / migrate cert issuance  
- Transfer of DB/filestore/addons/config / streaming  
- Selected Stage transfer  
- Migration Token burn  
- License deactivation / destination Production activation  
- Domain cutover / source shutdown / archive/purge  
- Cross-host License rebind / rollback after cutover  

## Authorization / progress

```text
Phase 17 = SCOPE REVIEW COMPLETE — IMPLEMENTATION NOT AUTHORIZED
Progress = 84% (unchanged)
Installer = 0.16.0-phase16
```

## Proposed weight (uncredited)

Plan table currently shows Phase 17 weight **`—`**.  
**Proposed weight: 5** (High complexity discovery/bootstrap/pairing; similar band to Phase 14).  
**Do not apply** until implementation is authorized and certified.

## Binding post-implementation outcome

```text
SOURCE DISCOVERY — COMPLETE
DESTINATION BOOTSTRAP — COMPLETE
MIGRATION PAIR — TRUSTED
READINESS — PASS / BLOCKED / NEEDS ACTION
NO DATA TRANSFER STARTED
SOURCE REMAINS ACTIVE
MIGRATION TOKEN NOT CONSUMED
```

## CLI proposal (do not implement now)

```bash
sudo soviez.sh --migration-discover <production-id>
sudo soviez.sh --migration-discovery-show <discovery-id>
sudo soviez.sh --migration-bootstrap-destination
sudo soviez.sh --migration-bootstrap-status <operation-id>
sudo soviez.sh --migration-pair <production-id> --destination <bootstrap-id>
sudo soviez.sh --migration-pair-status <pair-id>
sudo soviez.sh --migration-readiness <pair-id>
sudo soviez.sh --migration-readiness-show <report-id>
sudo soviez.sh --migration-abort <pair-id>
sudo soviez.sh --migration-status <operation-id>
sudo soviez.sh --migration-reattach <operation-id>
sudo soviez.sh --migration-retry <operation-id>
sudo soviez.sh --migration-recover <operation-id>
```

Require: exact IDs, interactive confirmation, non-TTY flags, JSON output, stable codes, offline/connected modes, secret-via-file/stdin, **no payload transfer**.

## Structured codes (minimum)

As listed in the Phase 17 review brief (`MIGRATION_SOURCE_*` … `MIGRATION_DATA_TRANSFER_NOT_AUTHORIZED`).
