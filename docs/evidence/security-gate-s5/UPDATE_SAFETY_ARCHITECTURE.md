# UPDATE_SAFETY_ARCHITECTURE

S5 wraps update-affecting operations with:

1. **Pre baseline** — firewall digest, Docker networks, published ports, DNS/outbound/DB placeholders.
2. **Controlled change** — package/Docker/service restarts only under policy; APT wait/backoff (never kill package managers).
3. **Post validation** — semantic network diff, DNS, outbound (skipped when offline/quarantine expected), Odoo↔PG, nginx/TLS sanity, public-port regression.
4. **Fail-closed** — inject/fault paths force FAIL; rollback triggers documented in UPDATE_ROLLBACK_TRIGGERS / NETWORK_ROLLBACK.
5. **Engine hook** — `src/update/engine.sh` invokes S5 when `SOVIEZ_S5_ENFORCE=1` or non-test Production path (Phase 15 fixture unit tests skip unless enforce set).

Evidence stays local under S5 op directories. Progress credit unchanged (99.5%).
