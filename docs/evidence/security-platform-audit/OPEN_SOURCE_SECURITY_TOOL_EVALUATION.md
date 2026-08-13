# Open-source security tool evaluation

| Tool | Function | Footprint | Air-gap | Odoo/PG fit | Rec |
|------|----------|-----------|---------|-------------|-----|
| auditd | syscall audit | Low | Yes | Good | Baseline optional |
| AIDE / Integrit | FIM | Med disk | Yes | Good | Baseline FIM |
| ClamAV | AV signatures | High RAM/disk | Partial | Attachment/scan | Optional / on-demand |
| YARA | Pattern/IOC | Low | Yes | DB dump/files | Yes for IOC |
| Wazuh | SIEM/agent | Heavy | Needs mgr | Overkill solo | Optional central |
| Falco | Runtime containers | Med + kernel | Hard | Good Docker | Optional advanced |
| CrowdSec | IP reputation | Med | Partial | Edge | Optional vs Fail2Ban |
| osquery | Inventory SQL | Med | Yes | Good | Optional |
| Lynis | Host audit | Low | Yes | Good | Periodic check |

**Reject “install everything”.** Prefer Fail2Ban (already) + AIDE + YARA + auditd + Lynis periodic; CrowdSec OR keep Fail2Ban; Wazuh/Falco only if operator wants central SOC.
