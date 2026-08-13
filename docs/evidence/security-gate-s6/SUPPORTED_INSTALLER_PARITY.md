# SUPPORTED_INSTALLER_PARITY

Focused `test_s6_installer_parity.sh` → **PASS**

- Dist version+SHA match expected `0.24.5.1-security-s5-corr1` / `78092b384b28dc45a93801c5d0acad7d90e4ca3e41cd0b235419c2eeeb6531ca`
- ERP == deploy (`cmp`)
- No `killall -9 apt` in supported paths
- Canonical modules present: `soviez_s5_apt_wait_for_lock`, quarantine, detection, legacy apt-lock assert
