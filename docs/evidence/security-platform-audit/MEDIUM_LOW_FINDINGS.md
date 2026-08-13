# Medium / low findings

| ID | Finding | Sev |
|----|---------|-----|
| M1 | Fail2Ban present (sshd/nginx) — good; no CrowdSec decision documented | LOW+ |
| M2 | Cloudflare IP refresh from live URL — good vs hardcode; needs offline/cache mode | MED |
| M3 | APT lock healer kills unattended-upgrade during install — can interrupt security updates mid-flight | MED |
| M4 | No SSH key-staged hardening automation | MED |
| M5 | No Webmin/Virtualmin detection | MED |
| M6 | No host FIM / ld.so.preload / SUID baseline | MED |
| M7 | Same-server backup ≠ off-host DR (policy gap) | MED |
| M8 | `admin_passwd = False` in ship `soviez.conf` overridden at run via CLI — OK if always set | LOW |
| M9 | Stage neutralization exists but not full security quarantine | MED |
| M10 | No wkhtmltopdf/network regression gate in update pre/post | MED |
| L1 | No `--link` / privileged / docker.sock in production run | INFO (positive) |
| L2 | Postgres not published (`-p`) in production | INFO (positive) |
| L3 | Random DB/admin/app secrets via `secrets` module | INFO (positive) |
| L4 | `list_db=False` + dbfilter | INFO (positive) |
