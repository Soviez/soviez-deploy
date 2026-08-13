# Backup Destination Protocol (Phase 16)

## Kinds
| Kind | Role | Encryption |
|------|------|------------|
| `local` | Required primary | Default ON |
| `s3` | Optional S3-compatible object storage | Mandatory |
| `sftp` | Optional SFTP (owner host) | Mandatory |

## Profiles
Destination profiles stored locally (profile_id, kind, path/endpoint, optional remote_path). Credentials in local secrets files (mode `600`) — **never** SaaS custody.

## Local
Writes under managed backup root per `production_id` / `backup_id`.

## S3-compatible
Put/list/test via profile; tests may use fixture root under backup workspace (`SOVIEZ_TEST_MODE`).

## SFTP
- `StrictHostKeyChecking=yes`, `BatchMode=yes`
- Identity from local secret / identity file
- Fixture path available in test mode

## Forbidden
- Soviez SaaS as destination
- Uploading backup payloads, keys, or destination secrets to SaaS
- Disabling encryption for remote kinds

## CLI
`--backup-destination-list|show|test`, `--backup … --destination PROFILE`
