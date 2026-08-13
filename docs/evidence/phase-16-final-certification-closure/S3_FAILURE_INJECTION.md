# S3 failure injection
Exercised: wrong access/secret, unavailable endpoint, missing bucket, prefix ownership mismatch,
before_first_part / middle_part / before_complete / after_complete_before_local interrupts,
during_download / during_verify / during_delete interrupts, secret redaction scan.
