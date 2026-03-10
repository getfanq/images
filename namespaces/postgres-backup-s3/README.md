# postgres-backup-s3

Backup PostgreSQL to S3. Supports on-demand and periodic scheduled backups. Based on Ubuntu 24.04 LTS with PostgreSQL 18 client.

## Image

```
ghcr.io/<org>/postgres-backup-s3:ubuntu24.04
```

## Usage

### One-shot backup

```bash
docker run --rm \
  -e S3_ACCESS_KEY_ID=key \
  -e S3_SECRET_ACCESS_KEY=secret \
  -e S3_BUCKET=my-bucket \
  -e S3_PREFIX=backup \
  -e POSTGRES_HOST=localhost \
  -e POSTGRES_DATABASE=dbname \
  -e POSTGRES_USER=user \
  -e POSTGRES_PASSWORD=password \
  ghcr.io/<org>/postgres-backup-s3:ubuntu24.04
```

### Docker Compose

```yaml
services:
  postgres:
    image: postgres:18
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
      POSTGRES_DB: mydb

  pgbackup:
    image: ghcr.io/<org>/postgres-backup-s3:ubuntu24.04
    depends_on:
      - postgres
    environment:
      SCHEDULE: "0 2 * * *"         # 02:00 UTC every day
      S3_REGION: us-east-1
      S3_ACCESS_KEY_ID: key
      S3_SECRET_ACCESS_KEY: secret
      S3_BUCKET: my-bucket
      S3_PREFIX: backup
      POSTGRES_HOST: postgres
      POSTGRES_DATABASE: mydb
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
      POSTGRES_EXTRA_OPTS: "--schema=public --blobs"
```

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `POSTGRES_HOST` | **required** | PostgreSQL hostname |
| `POSTGRES_PORT` | `5432` | PostgreSQL port |
| `POSTGRES_DATABASE` | **required** | Comma-separated list of databases to back up (or set `POSTGRES_BACKUP_ALL=true`) |
| `POSTGRES_USER` | **required** | PostgreSQL user |
| `POSTGRES_PASSWORD` | **required** | PostgreSQL password |
| `POSTGRES_EXTRA_OPTS` | `` | Extra options passed to `pg_dump` / `pg_dumpall` |
| `POSTGRES_BACKUP_ALL` | `**None**` | Set to `true` to dump all databases with `pg_dumpall` |
| `S3_ACCESS_KEY_ID` | **required** | AWS / S3-compatible access key |
| `S3_SECRET_ACCESS_KEY` | **required** | AWS / S3-compatible secret key |
| `S3_BUCKET` | **required** | Target S3 bucket name |
| `S3_PREFIX` | `` | Key prefix (folder) inside the bucket |
| `S3_REGION` | `us-east-1` | AWS region |
| `S3_ENDPOINT` | `**None**` | Custom endpoint URL for S3-compatible storage (e.g. `https://s3.example.com`) |
| `S3_S3V4` | `no` | Set to `yes` to force Signature Version 4 |
| `S3_FILE_NAME` | `**None**` | Override the generated filename (without extension) |
| `SCHEDULE` | `**None**` | Cron expression for periodic backups (see below). Unset = run once and exit. |
| `ENCRYPTION_PASSWORD` | `**None**` | Encrypt the dump with AES-256-CBC before uploading |

## Scheduling

Set `SCHEDULE` to a standard 5-field cron expression or one of the special strings supported by Ubuntu cron:

| Value | Meaning |
|---|---|
| `0 2 * * *` | Every day at 02:00 UTC |
| `@daily` | Once a day at midnight |
| `@hourly` | Once an hour |
| `@weekly` | Once a week |
| `@monthly` | Once a month |

When `SCHEDULE` is set the container stays running with `cron -f` as PID 1. When unset it runs the backup immediately and exits.

## Backup File Naming

| Scenario | Path in bucket |
|---|---|
| Single database | `<S3_PREFIX>/<database>_<timestamp>.sql.gz` |
| Multiple databases (comma-separated) | `<S3_PREFIX>/<database>_<timestamp>.sql.gz` (one file per DB) |
| `POSTGRES_BACKUP_ALL=true` | `<S3_PREFIX>/all_<timestamp>.sql.gz` |
| `S3_FILE_NAME` set (single DB) | `<S3_PREFIX>/<S3_FILE_NAME>_<database>.sql.gz` |
| `S3_FILE_NAME` set (backup all) | `<S3_PREFIX>/<S3_FILE_NAME>.sql.gz` |

When `ENCRYPTION_PASSWORD` is set the file gets an additional `.enc` suffix.

## Encryption

Backups are encrypted with OpenSSL AES-256-CBC + PBKDF2. Decrypt with:

```bash
openssl enc -aes-256-cbc -pbkdf2 -d \
  -in backup.sql.gz.enc \
  -out backup.sql.gz \
  -k <ENCRYPTION_PASSWORD>
```

## S3-Compatible Storage

Pass `S3_ENDPOINT` to use any S3-compatible provider (MinIO, Cloudflare R2, Backblaze B2, etc.):

```bash
-e S3_ENDPOINT=https://s3.example.com
```

## Building

```bash
# Build the image
./build.sh --all

# Build and push
./build.sh --all --push

# Dry run
./build.sh --all --dry-run
```

## Installed Software

| Package | Version |
|---|---|
| Ubuntu | 24.04 LTS (Noble Numbat) |
| PostgreSQL client | 18 (from PGDG) |
| AWS CLI | latest from Ubuntu apt |
| OpenSSL | system |
| cron | system |
