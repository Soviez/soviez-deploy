# Host persistence / FIM audit

Current: **no** baseline for ld.so.preload, unexpected libs, SUID/SGID, capabilities, root UID shells, cron, systemd, rc.local, profile, /tmp /dev/shm executables.

Design: baseline at install + periodic detect-only; incident mode evidence pack; no auto-removal.
