# Owner Decisions — Phase 17 Scope Review

**Status:** OPEN — must not be silently assumed. Implementation authorization should close these.

| ID | Decision | Recommendation (non-binding) |
|----|----------|------------------------------|
| OD-01 | Recent verified Full backup before readiness PASS, or only before transfer? | Capability healthy for PASS; recent Full before transfer |
| OD-02 | Maximum backup age before migration starts | Owner picks (e.g. 24–72h) |
| OD-03 | Trust protocol: mTLS, SSH certs, or app-signed? | App-signed for pairing; SSH/mTLS for later transfer tests |
| OD-04 | Source-initiate vs destination-initiate pairing? | Source-initiate or owner-authorized explicit both |
| OD-05 | Exact fingerprint confirmation UX | Interactive + non-TTY explicit flags |
| OD-06 | Pairing credential TTL | Short (e.g. 1–24h) |
| OD-07 | Soft-reserve Migration Token in Phase 17? | **No** — eligibility only |
| OD-08 | Bootstrap before Migration Token purchase? | Allow bootstrap; block readiness PASS if required |
| OD-09 | Initial Linux distros/versions | Align with current `--new`/legacy support matrix |
| OD-10 | Initial architectures | amd64 required; arm64 optional |
| OD-11 | IPv6 required or optional? | Optional |
| OD-12 | Min free-space margin on destination | e.g. transfer estimate + 20–30% |
| OD-13 | All Stages displayed, unselected by default? | **Yes** |
| OD-14 | Expired Stages selectable? | Display; select blocked or advanced-only |
| OD-15 | Non-sensitive SaaS metadata allowlist | As listed in Source Discovery / Sovereignty First |
| OD-16 | Connectivity test: SSH, mTLS, or both? | Start SSH; mTLS optional |
| OD-17 | Dest install exact source version vs latest compatible? | Exact source digest first |
| OD-18 | Discovery/readiness report TTL | e.g. 24–72h |
| OD-19 | Offline pairing package export/import? | Yes, desirable |
| OD-20 | WARNING vs BLOCKED thresholds | Publish matrix in implementation |
| OD-21 | Install Nginx at bootstrap or Phase 18? | Minimal proxy later; defer migrate landing to 18 |
| OD-22 | Pull images now or only validate registry access? | Validate access; pull optional |
| OD-23 | Exact Phase 20 token consume event | `migrate_license_ip` success after receipt |
| OD-24 | Temporary bootstrap identity auto-expiry? | **Yes** |
| OD-25 | Clock skew tolerance | e.g. 120–300s |

Commercial and destructive policies remain owner-approved.
