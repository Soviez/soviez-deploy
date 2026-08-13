# TEST_PLAN — Implementation-ready

A. Master-plan/scope: canonical topic; conflicts; Phase 24 boundary; no purge/App Store leak  
B. Entitlement: annual+offline_update_bundle; missing capabilities; expired/revoked/refunded/disputed; wrong License; provider-neutral  
C. Issuance: exact targeting; compatible/incompatible; Registry timeout; signature; deterministic rebuild; no credential leak  
D. Manifest/signature: tamper; wrong signer; unknown/revoked trust; digest mismatch  
E. Targeting/replay: wrong License/env/Device; clone; repeat inspect; duplicate apply; recover  
F. Expiry/clock: not-before; expired; clock rollback; trusted-time; new revocation package  
G. Payload: OCI; addons; unsigned; corrupt; bomb; traversal; symlink; disk full  
H. Compatibility: skip version; arch/OS/PG/UUID/addon; conflicting op  
I. Backup: fresh/stale/fail; restore-test; pinned rollback  
J. Offline apply: happy path; failures; rollback; reboot each step; no internet  
K. Reconciliation: export/import; forged; conflict; unreconciled; manual resolution  
L. Security: forged/downgrade/replay/trust-root/cred-leak/exec-before-verify/LG bypass/cross-tenant  
M. Integration lab: disposable ledger; Registry fixture; OCI; signed bundle; disconnected dest; PG/filestore; candidate; backup; rollback; reboot; later reconcile
