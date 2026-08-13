# NETWORK_SEMANTIC_DIFF

Compares pre vs post: firewall digest, Docker network set, published port maps for Odoo/PG. Flags unexpected public bindings and firewall digest drift.

Does not treat “all containers running” as PASS. Focused suite + fault inject: PASS (inject paths correctly FAIL).
