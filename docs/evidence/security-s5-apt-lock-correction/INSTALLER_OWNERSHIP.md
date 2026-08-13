# INSTALLER_OWNERSHIP

## Decision: Case A — dual Production wizard still supported

`soviez-deploy/soviez.sh` is **not** legacy-reference-only for operators.

### Evidence

| Source | Finding |
|--------|---------|
| `PRODUCT_CONSTITUTION.md` | Canonical future source = `soviez-sh`; legacy listed as reference during discovery |
| `src/security/platform/legacy_bridge.sh` | Dual-installer model: ERP + soviez-deploy MUST match S1/S2 security semantics; byte-identical sync |
| `tests/security/platform/test_legacy_installer_static.sh` | Asserts ERP == deploy and safety gates |
| `soviez-saas` docs / `userguide.md` / `installerguide.md` | Still directs operators to `soviez-deploy` / `curl … soviez.sh` |
| Phase 24 BASELINE | Labels deploy “Legacy read-only” for *discovery* — does not remove Production customer path |

### Classification

| Path | Role |
|------|------|
| `soviez-sh/src/*` → `dist/soviez.sh` | Canonical modular runtime/security |
| `Soviez ERP/soviez.sh` | Supported Production wizard (source of dual pair) |
| `soviez-deploy/soviez.sh` | Supported Production wizard copy (byte-identical to ERP) |
| SaaS `curl https://soviez.sh` | Currently resolves to deploy lineage (operator path) |

### Required remediation (this closure)

Because Case A applies: replace unsafe `heal_apt_locks` kill/rm in **both** ERP and deploy with canonical S5 wait-or-fail policy. Do not leave kill logic “dead but present.”

### Not Case C

Fail-closed deprecation alone would strand SaaS-documented operators without an updated download path; SaaS UI is frozen for unrelated changes, so dual-wizard must be made safe.
