# ClamAV

Module: `src/security/detection/clamav.sh`
Complementary to YARA. On-access scope excludes PGDATA. Filestore quarantine scan invokes ClamAV when available. Auto-install only if `SOVIEZ_CLAMAV_AUTO_INSTALL=1`.
