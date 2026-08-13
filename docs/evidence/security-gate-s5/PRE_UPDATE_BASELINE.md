# PRE_UPDATE_BASELINE

`soviez_s5_baseline_capture` (phase=pre) records firewall digest, Docker networks JSON, Odoo/Postgres published ports, DNS/outbound/DB status, and `offline_expected` when `SOVIEZ_S5_OFFLINE=1` or `SOVIEZ_S5_QUARANTINE=1`.

Success criteria for later validation are **semantic equivalence** of protected posture (no new public 8069/5432, firewall intent preserved), not mere container `Up` state.
