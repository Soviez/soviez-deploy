# OS update policy audit

- unattended-upgrades may run on Ubuntu hosts
- Installer APT lock healer can kill unattended-upgrade during install
- No Soviez policy documenting: defer reboot, coordinate Docker restart, validate network after kernel/Docker/Nginx upgrades

Future policy: security updates allowed; service-impacting upgrades require maintenance window + Gate S5 matrix.
Do **not** disable security updates by default.
