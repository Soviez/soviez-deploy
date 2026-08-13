# Secret handling audit
Passphrase: env/file only; openssl `-pass env:`.
Destination secrets mode 600; not in manifest.
Manifest key local HMAC only.
No secrets in CLI argv by design.
