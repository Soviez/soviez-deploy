# CHANGED_FILES — S2
## Created
- src/security/platform/{firewall,firewall_ufw,firewall_firewalld,firewall_nftables,docker_firewall,nginx_edge,cloudflare,edge,ssh,brute_force,management_surface,host_baseline,persistence_audit,s2_rollback,s2_gate}.sh
- share/security/cloudflare/ips-v4.lkg.json
- tests/security/run_security_gate_s2.sh
- tests/security/platform/test_fw_*.sh test_nginx_*.sh test_trusted_*.sh test_cloudflare_*.sh test_edge_*.sh test_ssh_*.sh test_brute_*.sh test_webmin_*.sh test_host_*.sh test_persistence_*.sh test_s2_*.sh
- docs/security/* S2 docs
- docs/evidence/security-gate-s2/*
## Modified
- VERSION → 0.24.2-security-s2
- build/assemble.sh, codes.sh, report.sh, legacy_bridge.sh, security_platform.sh, s1_platform.sh, run_all.sh
- phase20/21/22/24 version allowlists
- PROJECT_STATE + governance

