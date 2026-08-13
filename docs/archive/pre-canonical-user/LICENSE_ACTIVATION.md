# License activation

## Manual activation (always available)

1. Install and open the system.
2. Copy the instance fingerprint from the ERP or installer output.
3. Generate a key in the Soviez customer portal (email verification required).
4. Paste the key. The system verifies **offline** inside your server.

This path remains fully supported and is unchanged by connected install.

## Automatic activation during `--new` (Phase 8)

When you run `soviez.sh --new --activation automatic`:

1. The installer reserves a License Slot on your account.
2. After provisioning, Soviez Cloud issues an activation key.
3. The key is stored locally on your server (mode `0600`) — it is **never** printed to the terminal or logs.
4. The installer calls the **official** Odoo activation method inside your ERP container:
   - Key is staged via a secure temporary file inside the container (not command-line arguments).
   - `action_activate_soviez_license` verifies and stores the license.
   - The temporary file is deleted immediately.
5. Your ERP is activated before you reach the login screen.

### Security properties

| Property | Detail |
|----------|--------|
| Official path | Same ORM method as manual paste — no bypass |
| Key in logs | **Never** — redaction enforced |
| Key in argv | **Never** — stdin staging only |
| Offline after activation | License verified locally; no continuous Cloud dependency |

## Deferred activation (`--activation manual`)

Choose manual during `--new` if you want to install first and activate later:

1. Install completes with state `completed_activation_pending`.
2. Open the ERP and copy the fingerprint.
3. Generate and paste the key in the customer portal as usual.

No activation key is applied automatically.

## Certification note

Automatic activation is certified with mock SaaS and an ORM stub in the test environment. Full certification against a live disposable Odoo ERP container is pending for Phase 8 PASS gate.

## Related

- [INSTALLATION.md](INSTALLATION.md) — full install flow
- [WHEN_SOVIEZ_CONNECTS_ONLINE.md](WHEN_SOVIEZ_CONNECTS_ONLINE.md) — connected operations
