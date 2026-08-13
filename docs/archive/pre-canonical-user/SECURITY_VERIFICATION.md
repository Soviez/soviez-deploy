# Security verification (customer-facing)

Your Soviez installer verifies cryptographic signatures before applying production updates or offline bundles. Unsigned script self-update is not supported.

Registry credentials used for image pulls are short-lived and cleaned up after the operation. Soviez does not embed privileged backend (service-role) credentials in the installer you run on your server.

You can ask your operator to run the local security scan gate shipped with the installer sources; it does not send your data to Soviez.
