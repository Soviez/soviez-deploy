# STALE_ARCHITECTURE_SCAN
## workers=0-only (src, excluding tests/docs/evidence)
hits=0
## public :8072 in src
hits=9
## --formworkers
hits=0
## public --merge-in
hits=0
## p15 in active tests
hits=0 (comment-only in erp_release_fixture.sh)
## latest deployment authority in tests
hits=0 active (1 explicit minio/minio:latest fixture pull in test_s5_offhost_fixture.sh — allowed per contract §13)
## modular CLI anchors
init: preserved in /Volumes/PortableSSD/soviez-project/soviez-deploy/src/host/bootstrap.sh
doctor: preserved in /Volumes/PortableSSD/soviez-project/soviez-deploy/src/cli/parse.sh
releases: preserved in /Volumes/PortableSSD/soviez-project/soviez-deploy/src/cli/parse.sh
release-status: preserved in /Volumes/PortableSSD/soviez-project/soviez-deploy/src/cli/parse.sh
tune: preserved in /Volumes/PortableSSD/soviez-project/soviez-deploy/src/cli/parse.sh
safe-mode: preserved in /Volumes/PortableSSD/soviez-project/soviez-deploy/src/cli/parse.sh
