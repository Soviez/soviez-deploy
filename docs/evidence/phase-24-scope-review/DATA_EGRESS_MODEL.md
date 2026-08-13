# DATA_EGRESS_MODEL.md

## Phase 24 may send externally (only if an operation already requires it)

Phase 24 is primarily **local hardening + CI**. Expected egress:

| Channel | Allowed | Notes |
|---------|---------|-------|
| CI secret-scan tooling (GitHub) | Metadata of repo files to scanner | No customer DB |
| Existing disclosed SaaS calls during regression tests | Per `DATA_EGRESS_CONTRACT.md` | Disposable fixtures only |
| Registry pull during security regression | Short-lived tickets | Ephemeral docker config |
| None for pure static suites | — | Preferred |

## Forbidden (unchanged)

- Business DB / filestore / attachments
- Unrestricted logs
- Passwords / private keys / activation keys in logs or SaaS
- Registry long-lived credentials
- SaaS payload relay
- Hidden telemetry / periodic phone-home
- Backup archives to SaaS

## New Phase 24-specific egress

None required for core hardening. If CI uses a SaaS scanner, disclose in workflow docs; never upload Production customer data.
