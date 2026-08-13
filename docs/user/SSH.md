# SSH

## Policy

`SOVIEZ_SSH_POLICY` default `staged` — hardening is applied carefully to avoid lockout.

## Safety

- SSH hardening may be **deferred** if lockout risk is detected
- Fail2Ban may be installed for brute-force protection (this is not Webmin)
- Do not disable SSH access without an out-of-band console

## Troubleshooting

If SSH hardening is deferred: review security report, ensure alternate access, then re-run `--security-harden` intentionally.
