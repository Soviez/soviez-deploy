# POST_UPDATE_VALIDATION

Post phase re-captures baseline fields and runs `soviez_s5_semantic_diff` plus DNS/outbound/DB/nginx/port checks.

PASS only if protected network posture holds and required connectivity checks match environment mode (online Production vs offline/quarantine). FAIL on inject flags or real regression. Authoritative focused suite: PASS.
