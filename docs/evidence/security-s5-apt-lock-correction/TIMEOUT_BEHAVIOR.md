# TIMEOUT_BEHAVIOR

## Default
120 seconds (`SOVIEZ_APT_LOCK_TIMEOUT` / `SOVIEZ_S5_APT_LOCK_TIMEOUT`).

## On timeout
- stdout: `PKG_LOCK_TIMEOUT`
- exit status: non-zero
- stderr: structured report + human message stating **no kill** and **no lock delete**
- Callers must abort the package-mutating operation (Needs Action / return 1 / die)

## What does not happen
- No SIGKILL of apt/dpkg/unattended-upgrades
- No deletion of lock files
- No silent retry beyond the bound without operator action

## Evidence
CORR-APT-002 / CORR-APT-008 unit; guest flock holder → TIMEOUT while holder remains alive (22.04/24.04).
