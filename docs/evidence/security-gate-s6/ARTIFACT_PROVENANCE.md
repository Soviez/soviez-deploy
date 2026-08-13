# ARTIFACT_PROVENANCE — Security Gate S6

| Field | Value |
|-------|--------|
| Prefer exact artifact | yes |
| Installer version | `0.24.5.1-security-s5-corr1` |
| `dist/soviez.sh` SHA256 | `78092b384b28dc45a93801c5d0acad7d90e4ca3e41cd0b235419c2eeeb6531ca` |
| VERSION bump for S6 | **none** |
| Product src changes for S6 | **none required** |
| Assemble during focused S6 | **skipped** (VERSION+SHA matched expected) |
| Published | **no** (local only) |
| Git commit claimed | **none** (do not falsely claim a commit) |
| Certification run ID | `s6-cert-2026-08-12T014258Z` |
| Environment | local Mac/Colima Docker; disposable fixtures; no live customer systems |
| Generated UTC | 2026-08-12T01:42:58Z |

## Source of truth
- Modular: `soviez-sh` (`VERSION`, `dist/soviez.sh`)
- Supported dual Production wizards: `Soviez ERP/soviez.sh` ↔ `soviez-deploy/soviez.sh` (byte-identical; apt-lock safe)
