# Image Cleanup

After a successful product update, Soviez keeps both your **current** ERP image and the previous (**rollback**) image for a safety window of about **24 hours**. That lets the installer restore the prior runtime if something goes wrong after switch.

When the safety window ends, Soviez can remove **only** unused Soviez-managed ERP images that nothing still references — not your current image, not the rollback image, and not images used by another Production, a Stage, or any container (running or stopped).

Soviez does **not** run broad Docker “prune everything” commands. Cleanup is exact and cautious. Free disk space may be less than the sum of image sizes because Docker shares layers between images.

You can ask for a dry-run report before any deletion. A new Production update on the same instance cancels a pending scheduled image cleanup so update work always takes priority.

Image cleanup never uploads your business data to Soviez SaaS.
