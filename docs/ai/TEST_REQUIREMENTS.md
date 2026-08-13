# Test requirements

## Future SaaS changes must cover
Stripe settlement; manual/admin grants; refund/reversal/dispute/chargeback; provider extensibility; slot concurrency; cross-license denial; monthly≠updates; annual=updates; Stage exact-license; migration token one-use; device auth; ticket replay; registry pull restrictions.

## Future local_license_guard changes must cover
Manual activation; valid/invalid key; unconfigured; allowlists; ledger; quarantine; shadow lock; rollback; UUID rotation; deactivation receipt; migration secret fail-closed; rebind; Cython packaging; licensed DB after module upgrade.

## Installer
Disclosure; digest pull cleanup; DNS Try Again/Abort; retention vs entitlement; no service-role in dist; restore round-trip; migrate resume.
