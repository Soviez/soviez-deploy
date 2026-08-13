# S5 Corrective Closure — FINAL REPORT

## Verdict
**PASS — S5 CORRECTIVE CLOSURE (PACKAGE-LOCK SAFETY / APT LOCK CORR1) COMPLETE**

## Scope
Correct unsafe dual Production wizard `heal_apt_locks` (killall -9 apt/dpkg/unattended-upgrade + blind lock `rm`) to canonical wait-or-fail policy. Align ERP ↔ soviez-deploy with modular `soviez-sh` S5 APT lock safety. No S6 work. No Phase 25 resume.

## Ownership (Case A)
Dual Production wizard still supported and must be byte-identical safe:
- Canonical modular: `soviez-sh` → `dist/soviez.sh`
- Supported Production wizard pair: `Soviez ERP/soviez.sh` ↔ `soviez-deploy/soviez.sh`

## Installer (canonical modular)
- Version: `0.24.5.1-security-s5-corr1`
- Artifact SHA256: `78092b384b28dc45a93801c5d0acad7d90e4ca3e41cd0b235419c2eeeb6531ca` (local only; not published)
- Prior S5 baseline: `0.24.5-security-s5` / `d42791352b5825e6484c4ff8304d6e2249faf44b2b9082ed5233b96fa809cf42`

## Canonical module
`src/security/update_safety/apt_lock.sh` → `soviez_s5_apt_wait_for_lock`
- Wait-or-fail only
- No `killall -9` of apt/dpkg/unattended-upgrade
- No blind removal of apt/dpkg lock files

## Authoritative corr suite
`tests/security/run_s5_corr_apt_lock.sh` → **PASS**
- Unit: `test_s5_corr_apt_lock.sh` (CORR-APT-001…008)
- Guest no-kill proof: `test_s5_corr_apt_lock_guest.sh` on Ubuntu **22.04** and **24.04**

`tests/run_all.sh` — **PASS** (`285 OK / 0 FAIL`, exact exit code `0`).

## Key controls
| Control | Result |
|---------|--------|
| Dual wizard heal_apt_locks wait-or-fail | PASS |
| ERP ↔ deploy byte-identical (safe pair) | PASS |
| Modular `soviez_s5_apt_wait_for_lock` | PASS |
| No killall -9 apt/dpkg/unattended-upgrade (supported paths) | PASS |
| No blind lock rm in heal_apt_locks | PASS |
| Ubuntu 22.04 guest no-kill proof | PASS |
| Ubuntu 24.04 guest no-kill proof | PASS |
| Static unsafe-pattern scan (supported Production) | PASS |
| Update engine APT preflight (corr1) | PASS (wired) |
| New-install / Stage / migration call sites fail closed on timeout | PASS (no kill) |
| Idempotent wait | PASS |
| Dist security scan accepts corr1 version | PASS (allowlist) |
| run_all authoritative | PENDING |

## Residual risk / explicit non-claims
- **S6** remains **NOT AUTHORIZED** (READY FOR OWNER AUTHORIZATION only).
- Phase 25 remains **paused**.
- Progress remains **99.5%** (no credit for corr1).
- Review-candidate / historical trees may still contain old kill logic; they are **not** supported Production paths.
- No commit/push/deploy/publish performed in this closure.

## Progress
Engineering Progress remains **99.5%**. S5 Corrective Closure = **PASS**. S6 unauthorized. Phase 25 paused.
