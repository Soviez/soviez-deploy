# SSH security audit

Current: Soviez.sh does **not** orchestrate SSH key staging / password disable / root disable.
UFW allows OpenSSH; Fail2Ban sshd jail present in ERP installer.

Safe automation vs operator confirmation:
| Action | Automate? |
|--------|-----------|
| Detect password auth / root login | Yes (report) |
| Install Fail2Ban if missing | Optional with confirm |
| Create staged admin + verify alternate login | OPERATOR_INTERACTION |
| Disable password / root | Only after verified alternate login |

Never auto-lockout existing hosts.
