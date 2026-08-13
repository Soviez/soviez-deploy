# DIST_SECURITY_SCAN

## Artifact
- Path: `soviez-sh/dist/soviez.sh`
- Version: `0.24.5.1-security-s5-corr1`
- SHA256: `78092b384b28dc45a93801c5d0acad7d90e4ca3e41cd0b235419c2eeeb6531ca`

## Allowlists updated
Phase 20/21/22 static forbidden + Phase 24 dist scan accept corr1 version string.

## APT lock
No executable `killall -9 apt…` lines in dist. Detector/regex strings in assert helpers are not executable healers.

## Result
**PASS** for corr1 version recognition + no-kill static expectation on dist.
