# Forbidden Prune Static Gate

`soviez_image_forbid_prune_static_gate` statically refuses broad prune patterns (e.g. `docker system prune`, `image prune -a`) in the cleanup code path.

Final cert calls the gate successfully after cleanup execute.
PASS — no broad prune allowed.
