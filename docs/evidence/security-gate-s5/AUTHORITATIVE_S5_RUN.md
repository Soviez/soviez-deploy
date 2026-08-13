# AUTHORITATIVE_S5_RUN

## Commands
```bash
SOVIEZ_S5_SKIP_NESTED_REGRESSIONS=1 bash tests/security/run_security_gate_s5.sh
# → PASS

bash tests/run_all.sh
# → PASS (258 OK / 0 FAIL, exit 0)
```

## Artifact
- Version: `0.24.5-security-s5`
- SHA256: `d42791352b5825e6484c4ff8304d6e2249faf44b2b9082ed5233b96fa809cf42`
- Not published

## Environment
Disposable Colima Docker; Ubuntu 22.04/24.04 privileged guests for firewall reload/reboot survival; MinIO disposable for off-host classify; no live customer systems.
