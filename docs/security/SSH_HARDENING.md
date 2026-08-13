# SSH staged hardening (S2)

Policies: `staged` (default preference), `keys_required`, `deferred`. PasswordAuthentication/PermitRootLogin are disabled only after a non-root sudo admin with authorized_keys is verified. Syntax-checked drop-ins; safe defer otherwise. Tests never mutate the developer workstation sshd.
