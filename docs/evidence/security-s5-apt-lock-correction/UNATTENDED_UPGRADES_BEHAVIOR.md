# UNATTENDED_UPGRADES_BEHAVIOR

## Policy
Unattended-upgrades is a **legitimate** lock owner. Corr1 **waits**; it does **not** kill `unattended-upgrade`.

## Runtime
- Owners include `pgrep -f unattended-upgrade`
- CORR-APT-004 exercises wait path with unattended-upgrade-like owner fixture
- On `PKG_LOCK_TIMEOUT`, operator guidance: wait for the process or schedule maintenance — do not `kill -9`

## Relationship to S5 package policy
Security patches via unattended-upgrades remain intentional. Disruptive service restarts remain gated by the S5 restart/reboot matrix (unchanged by corr1).
