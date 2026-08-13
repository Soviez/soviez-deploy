# BASELINE

- S1–S5 = PASS
- Installer before corr: `0.24.5-security-s5`
- SHA256: `d42791352b5825e6484c4ff8304d6e2249faf44b2b9082ed5233b96fa809cf42`
- run_all: 258 OK / 0 FAIL
- Defect: dual wizard `heal_apt_locks` used `killall -9 apt apt-get dpkg unattended-upgrade` + `rm` lock files
- Modular soviez-sh already wait-only (S5)
- Progress 99.5%; S6 unauthorized; Phase 25 paused
