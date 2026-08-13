# Threat model (mandatory set)

For each: precondition | prevention | detection | containment | recovery | residual risk

## T01 Stolen Odoo admin credentials
Pre: phishing/session theft. Prev: strong admin_passwd + UI password, MFA (future), list_db=False. Det: login anomalies. Cont: revoke sessions, rotate admin_passwd. Rec: password reset. Residual: insider admin.

## T02 Weak/default credentials
Pre: admin/admin. Prev: random secrets at install (current positive). Det: TEST-SEC-014. Cont: force rotate. Residual: operator-chosen weak passwords post-install.

## T03 Malicious Odoo administrator
Pre: trusted admin abuse. Prev: least PG privilege (C1 fix). Det: DB scanner on server actions. Cont: quarantine egress. Residual: business data abuse.

## T04 Compromised browser/session
Pre: XSS/malware. Prev: HTTPS, secure cookies, proxy_mode. Det: session audit. Cont: invalidate sessions. Residual: concurrent sessions.

## T05 Malicious server action
Pre: admin or SQL write to ir.actions.server. Prev: PG least privilege; quarantine. Det: YARA/DB scanner. Cont: disable action (operator), not auto-delete. Residual: zero-day patterns.

## T06 Malicious custom addon
Pre: untrusted module. Prev: signed addon policy (future); Stage scan. Det: code YARA. Cont: uninstall under maintenance. Residual: Enterprise opaque code.

## T07 SQL injection
Pre: vuln addon. Prev: ORM discipline; least privilege. Det: auditd/WAF optional. Cont: isolate DB. Residual: app bugs.

## T08 PostgreSQL privilege escalation
Pre: app role superuser (CURRENT C1). Prev: NOSUPERUSER app role. Det: role attribute checks. Cont: revoke. Residual: extension owners.

## T09 COPY PROGRAM
Pre: superuser or pg_execute_server_program. Prev: revoke. Det: TEST-SEC-002. Cont: network quarantine. Residual: other RCE in extensions.

## T10 Arbitrary server file R/W
Pre: pg_read/write_server_files. Prev: revoke. Det: TEST-SEC-003/004. Cont: same. Residual: volume mounts.

## T11 Container escape
Pre: kernel vuln / privileged. Prev: no privileged, no sock. Det: Falco optional. Cont: host IR. Residual: kernel 0day.

## T12 Docker socket abuse
Pre: sock mounted. Prev: never mount in app (current positive). Det: inspect mounts. Cont: remove mount. Residual: host root.

## T13 Public Docker ports
Pre: -p all-ifaces (C2). Prev: 127.0.0.1 bind / DOCKER-USER. Det: TEST-SEC-005/006. Cont: rebind. Residual: misconfig.

## T14 Malicious database backup
Pre: restore dirty dump. Prev: quarantine Gate S4. Det: DB scanner. Cont: blocked egress. Residual: novel IOC.

## T15 Malicious attachment
Pre: upload. Prev: ClamAV on-demand; size limits. Det: AV/YARA. Cont: quarantine filestore object. Residual: polyglots.

## T16 Miner/downloader
Pre: RCE via T09. Prev: C1 fix. Det: CPU/YARA/stratum. Cont: evidence + isolate. Residual: fileless.

## T17 Reverse shell
Pre: RCE. Prev: egress observe/allowlist optional. Det: conn patterns. Cont: firewall drop. Residual: DNS tunneling.

## T18 LD_PRELOAD/rootkit
Pre: root. Prev: FIM on ld.so.preload. Det: AIDE. Cont: rebuild host. Residual: advanced rootkits.

## T19 SSH brute force
Pre: password auth. Prev: keys + Fail2Ban. Det: jail logs. Cont: ban. Residual: stolen key.

## T20 Webmin/Virtualmin
Pre: public :10000. Prev: detect+harden. Det: port scan report. Cont: allowlist. Residual: 0day in panel.

## T21 Firewall misconfiguration
Pre: flush/reset. Prev: no broad flush; snapshots. Det: Gate S5 tests. Cont: restore snapshot. Residual: Docker/UFW race.

## T22 Docker/firewall restart regression
Pre: restart. Prev: validation matrix. Det: TEST-SEC-012/013. Cont: rollback firewall rules carefully. Residual: race.

## T23 Backup compromise
Pre: stolen backup. Prev: encrypt + off-host ACL. Det: access logs. Cont: rotate secrets in backup. Residual: old backups.

## T24 Secret leakage
Pre: logs/inspect. Prev: hygiene Phase 24; reduce env secrets. Det: secret_scan. Cont: rotate. Residual: historical logs.

## T25 Compromised signing/update
Pre: bad key. Prev: Phase 24 STRICT_SIG. Det: verify fail. Cont: quarantine artifact. Residual: stolen offline key.

## T26 Compromised Registry credential
Pre: leak. Prev: ephemeral tickets Phase 24. Det: audit. Cont: revoke. Residual: long-lived legacy.

## T27 Malicious restore/migration source
Pre: untrusted dump. Prev: quarantine. Det: scanner. Cont: never auto-promote. Residual: novel.

## T28 Compromised operator laptop/root
Pre: laptop malware. Prev: keys on hardware token; least sudo. Det: out-of-band. Cont: rotate all host secrets. Residual: ultimate.

Boundary goal:
```text
COMPROMISED ODOO ≠ COMPROMISED POSTGRESQL HOST ≠ COMPROMISED SERVER
```
