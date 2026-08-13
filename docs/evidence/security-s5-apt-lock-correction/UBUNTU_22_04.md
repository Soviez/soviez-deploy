# UBUNTU_22_04

## Guest
`ubuntu:22.04` (Docker, platform linux/arm64)

## Proof
`test_s5_corr_apt_lock_guest.sh` → flock hold → wait timeout → holder alive → release → `PKG_LOCK_RELEASED`

## Result
**PASS** — `NO_KILL_PROOF_PASS` / `PASS ubuntu22`
