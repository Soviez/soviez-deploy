# S3 real fixture
- Engine: MinIO `minio/minio:RELEASE.2024-12-18T13-15-44Z` on disposable Docker network `soviez-p16-net`
- Endpoint: http://127.0.0.1:19000 (fixture HTTP only — TLS not terminated in disposable cert fixture; documented limitation)
- Bucket: `soviez-p16-cert` (exact); prefix `backups/`
- Credentials: local secret file mode 600; never argv/logs/inventory
- Client: pure-stdlib SigV4 path-style multipart (no boto3/aws CLI required)
- Test: `tests/integration/test_backup_s3_real.sh` PASS
