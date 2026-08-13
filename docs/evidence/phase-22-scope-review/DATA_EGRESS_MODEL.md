# Data Egress Model (Sovereignty First)

## Never send to SaaS

source/dest DB content or dumps · filestore · attachments · customer/employee/accounting records · source archive content · backup content · credentials · private keys · cert private keys · server access keys · unrestricted logs · deletion manifests with sensitive filenames · access logs · request bodies

## Permitted metadata (where necessary)

License ID · migration authorization ID · cutover/archive operation IDs · source/destination environment IDs · traffic-owner / rollback-window / archive state · backup IDs · public fingerprints · certificate metadata · retention deadlines · non-sensitive infrastructure IDs · aggregate health · signed checksums · timestamps · non-sensitive failure codes · readiness status

## Bans

No hidden telemetry · no remote shell through SaaS · no SaaS backup relay · no archive payload upload to SaaS
