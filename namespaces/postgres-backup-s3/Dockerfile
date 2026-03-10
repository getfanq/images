ARG UBUNTU_VERSION=24.04
ARG POSTGRES_VERSION=18

FROM ubuntu:${UBUNTU_VERSION}

# Re-declare ARGs after FROM so they are in scope
ARG UBUNTU_VERSION
ARG POSTGRES_VERSION

LABEL org.opencontainers.image.title="postgres-backup-s3"
LABEL org.opencontainers.image.description="Backup PostgreSQL to S3 with optional scheduling and encryption"
LABEL org.opencontainers.image.vendor="fanq"
LABEL version.ubuntu="${UBUNTU_VERSION}"
LABEL version.postgres="${POSTGRES_VERSION}"

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=C.UTF-8

# Install PostgreSQL 18 client from the official PGDG apt repository,
# plus s3cmd for S3 uploads, openssl for encryption, and cron for scheduled backups.
# Note: awscli is not available in Ubuntu 24.04 apt repos; s3cmd covers all required
# S3 operations (put, custom endpoints, signature versions) with no extra dependencies.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
    # Add PGDG apt repo
    && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
        | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] \
        https://apt.postgresql.org/pub/repos/apt \
        $(lsb_release -cs)-pgdg main" \
        > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        postgresql-client-${POSTGRES_VERSION} \
        s3cmd \
        openssl \
        cron \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV POSTGRES_DATABASE=**None** \
    POSTGRES_BACKUP_ALL=**None** \
    POSTGRES_HOST=**None** \
    POSTGRES_PORT=5432 \
    POSTGRES_USER=**None** \
    POSTGRES_PASSWORD=**None** \
    POSTGRES_EXTRA_OPTS='' \
    S3_ACCESS_KEY_ID=**None** \
    S3_SECRET_ACCESS_KEY=**None** \
    S3_BUCKET=**None** \
    S3_FILE_NAME=**None** \
    S3_REGION=us-east-1 \
    S3_ENDPOINT=**None** \
    S3_S3V4=no \
    S3_PREFIX=**None** \
    SCHEDULE=**None** \
    ENCRYPTION_PASSWORD=**None**

COPY backup.sh /backup.sh
COPY run.sh /run.sh

RUN chmod +x /backup.sh /run.sh

ENTRYPOINT []
CMD ["sh", "/run.sh"]
