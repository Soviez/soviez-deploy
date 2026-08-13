# UPDATE_ROLLBACK_TRIGGERS

S5 treats these as fail-closed / rollback-triggering for update safety:

- Semantic network/firewall/port regression vs pre baseline
- DNS / outbound / Odoo-PG validation FAIL (when required for mode)
- Public port protection FAIL
- PDF check FAIL when enforced on a path that requires it
- Package-policy UNSAFE healer detection (must not ship)

Engine enforcement: `SOVIEZ_S5_ENFORCE=1` or non-test Production update path.
