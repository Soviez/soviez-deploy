# DPKG_CONSISTENCY_POLICY

## Soft detect
`soviez_pkg_dpkg_inconsistent`:
- Presence of `/var/lib/dpkg/updates/tmp.i`, or
- `dpkg --audit` matching needs-reinstall / unfinished / broken

## Codes
- `PKG_STATE_INCONSISTENT` — informational when no live lock holder blocks; callers may continue or guide operators
- Corr1 does **not** auto-run `dpkg --configure -a` or force-remove locks

## Rationale
Killing package managers was a primary path into inconsistent dpkg state. Wait-or-fail avoids creating that class of damage. Remediation of an already-broken dpkg tree is an operator/maintenance concern outside automatic heal.
