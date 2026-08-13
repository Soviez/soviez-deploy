# Security test plan (implementation-ready)

TEST-SEC-001 … 024 as specified in mission (role, COPY PROGRAM, files, ports, HTTPS, proxy, DNS, outbound, firewall/docker restart, no default admin, no dangerous PG roles, no privileged, DB IOC detect/no-exec, quarantine egress, cleanup, ZATCA unchanged, log rotation, idempotent harden, reboot survive).

Additional: docker.sock absent; secrets not in logs; weak password reject; migration secrets refreshed; Webmin detect; SUID baseline; systemd/cron; ld.so.preload; miner IOC; severity report; rollback; repeated scan; multi-tenant SaaS isolation where applicable.

Critical containment tests require real Ubuntu+Docker+PG+firewall — not fixture-only certification.
