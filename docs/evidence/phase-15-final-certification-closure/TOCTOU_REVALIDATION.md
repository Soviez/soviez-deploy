# TOCTOU Revalidation

Before each exact `docker image rm`, cleanup re-runs classify/reference checks so a digest that gained a new reference between dry-run and delete is skipped.

Prevents race deletes against newly started containers or newly written inventory.
