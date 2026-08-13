# UBUNTU_24_04

## Guest
`ubuntu:24.04` (Docker, platform linux/arm64)

## Proof
Same guest script as 22.04: flock hold → `PKG_LOCK_TIMEOUT` without killing holder → post-release `PKG_LOCK_RELEASED`

## Result
**PASS** — `NO_KILL_PROOF_PASS` / `PASS ubuntu24`
