# Image Reference Scan

`soviez_image_collect_references` aggregates digest refs from:
- Running containers
- Stopped containers
- Production inventory (`identity.json`)
- Stage inventory
- Active update candidates
- Rollback manifests
- Active operations / recovery sets

Any hit protects the image from eligibility.
