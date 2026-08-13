# MANUAL_AND_AUTOMATIC_ACTIVATION.md

## Manual Activation

Instance → Activation → Manual Activation keeps the existing product path:

- Shows `license_key` from the real `licenses` row (when present)
- Copy action
- Guidance to Settings → Instance License
- Does **not** replace the Overview “Activate Server License” / burn-and-generate flow

## Automatic Activation

Instance → Activation → Automatic Activation surfaces Device/server relationship from `instance-summary`:

- Connected / Disconnected / Needs Action
- Authorize / Reauthorize / Revoke Server Access (real Device APIs when Devices exist)
- Distinguishes Revoke Server Access vs Unlink-from-License (unlink only if policy supports)

## Demo seed state

Seeded licenses have no Device rows yet → Automatic Activation shows Disconnected / “No authorized Device…”. Manual key remains available (`licenseKeyPresent: true`).
