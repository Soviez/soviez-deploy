# Update Candidate Isolation Protocol

- DB/filestore cloned from recovery set — never live Production mounts
- Separate container `soviez-upd-cand-<op>` and network `soviez-upd-net-<op>`
- Real Docker path (Colima): labeled ERP image + disposable PostgreSQL; upgrade via `soviez-bin -i/-u … --stop-after-init`; HTTP `/web/login` validation
- Neutralization: mail/cron/webhooks/payments/outbound/background jobs disabled
- `license_slot_consumed=false`; role=`update_candidate`; temporary=1
- License Guard identity: `soviez.update-candidate-identity.v1` (see `UPDATE_LICENSE_GUARD_CANDIDATE_PROTOCOL.md`); no bypass env
- Does not consume Stage License or Production slot
- Cleanup removes candidate container/network/workspace; rollback set retained for safety window
- Collision checks against live database_path/filestore_path
- Incompatible custom addon → `UPDATE_CANDIDATE_UPGRADE_FAILED`; Production digest unchanged
