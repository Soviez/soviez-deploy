# S3 multipart and resume
- Part size >= 5MiB; multipart create → upload parts → complete
- State file tracks owned upload_id + parts; idempotent complete
- Resume after middle_part interrupt reuses owned upload_id
- Abandoned multipart abort only for operation-owned upload IDs
