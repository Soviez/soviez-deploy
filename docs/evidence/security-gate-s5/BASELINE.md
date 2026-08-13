# BASELINE

Prior gate: Security Gate S4 — installer `0.24.4-security-s4`, SHA256 `fdbf6ea35f5e318fd4b7ff737ecf2e0bed443629b12813c2f172456572072c25`, PASS.

S5 target: installer `0.24.5-security-s5`, SHA256 `d42791352b5825e6484c4ff8304d6e2249faf44b2b9082ed5233b96fa809cf42`.

S5 captures pre-change network/firewall/Docker/port/DNS/outbound/DB baselines via `soviez_s5_baseline_capture` before update-related mutations; post phase compares semantically (`soviez_s5_semantic_diff`). “Containers Up” alone is never success.
