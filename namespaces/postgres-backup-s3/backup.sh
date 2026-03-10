#! /bin/sh

set -eo pipefail

if [ "${S3_ACCESS_KEY_ID}" = "**None**" ]; then
  echo "You need to set the S3_ACCESS_KEY_ID environment variable."
  exit 1
fi

if [ "${S3_SECRET_ACCESS_KEY}" = "**None**" ]; then
  echo "You need to set the S3_SECRET_ACCESS_KEY environment variable."
  exit 1
fi

if [ "${S3_BUCKET}" = "**None**" ]; then
  echo "You need to set the S3_BUCKET environment variable."
  exit 1
fi

if [ "${POSTGRES_DATABASE}" = "**None**" ] && [ "${POSTGRES_BACKUP_ALL}" != "true" ]; then
  echo "You need to set the POSTGRES_DATABASE environment variable."
  exit 1
fi

if [ "${POSTGRES_HOST}" = "**None**" ]; then
  if [ -n "${POSTGRES_PORT_5432_TCP_ADDR}" ]; then
    POSTGRES_HOST=$POSTGRES_PORT_5432_TCP_ADDR
    POSTGRES_PORT=$POSTGRES_PORT_5432_TCP_PORT
  else
    echo "You need to set the POSTGRES_HOST environment variable."
    exit 1
  fi
fi

if [ "${POSTGRES_USER}" = "**None**" ]; then
  echo "You need to set the POSTGRES_USER environment variable."
  exit 1
fi

if [ "${POSTGRES_PASSWORD}" = "**None**" ]; then
  echo "You need to set the POSTGRES_PASSWORD environment variable or link to a container named POSTGRES."
  exit 1
fi

# Build s3cmd argument string
S3CMD_ARGS="--access_key=${S3_ACCESS_KEY_ID} --secret_key=${S3_SECRET_ACCESS_KEY} --region=${S3_REGION} --no-progress"

if [ "${S3_ENDPOINT}" != "**None**" ]; then
  # Strip trailing slash from endpoint if present
  S3_ENDPOINT_CLEAN=$(echo "$S3_ENDPOINT" | sed 's|/$||')
  S3CMD_ARGS="${S3CMD_ARGS} --host=${S3_ENDPOINT_CLEAN} --host-bucket=${S3_ENDPOINT_CLEAN}/%(bucket)s"
fi

if [ "${S3_S3V4}" = "yes" ]; then
  S3CMD_ARGS="${S3CMD_ARGS} --signature-v2=False"
fi

export PGPASSWORD=$POSTGRES_PASSWORD
POSTGRES_HOST_OPTS="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER $POSTGRES_EXTRA_OPTS"

# Determine S3 destination path prefix
if [ "${S3_PREFIX}" = "**None**" ] || [ -z "${S3_PREFIX}" ]; then
  S3_PATH="s3://${S3_BUCKET}/"
else
  S3_PATH="s3://${S3_BUCKET}/${S3_PREFIX}/"
fi

upload_file() {
  local src=$1
  local dest=$2
  echo "Uploading to ${dest}"
  # shellcheck disable=SC2086
  s3cmd $S3CMD_ARGS put "$src" "$dest" || exit 2
  echo "SQL backup uploaded successfully"
  rm -f "$src"
}

encrypt_file() {
  local src=$1
  local enc="${src}.enc"
  echo "Encrypting ${src}"
  if ! openssl enc -aes-256-cbc -pbkdf2 -in "$src" -out "$enc" -k "$ENCRYPTION_PASSWORD"; then
    >&2 echo "Error encrypting ${src}"
    exit 1
  fi
  rm -f "$src"
  echo "$enc"
}

if [ "${POSTGRES_BACKUP_ALL}" = "true" ]; then
  SRC_FILE=/tmp/dump_all.sql.gz
  DEST_FILE=all_$(date +"%Y-%m-%dT%H:%M:%SZ").sql.gz

  if [ "${S3_FILE_NAME}" != "**None**" ]; then
    DEST_FILE=${S3_FILE_NAME}.sql.gz
  fi

  echo "Creating dump of all databases from ${POSTGRES_HOST}..."
  # shellcheck disable=SC2086
  pg_dumpall $POSTGRES_HOST_OPTS | gzip > "$SRC_FILE"

  if [ "${ENCRYPTION_PASSWORD}" != "**None**" ]; then
    SRC_FILE=$(encrypt_file "$SRC_FILE")
    DEST_FILE="${DEST_FILE}.enc"
  fi

  upload_file "$SRC_FILE" "${S3_PATH}${DEST_FILE}"
else
  OIFS="$IFS"
  IFS=','
  for DB in $POSTGRES_DATABASE; do
    IFS="$OIFS"

    SRC_FILE=/tmp/dump_${DB}.sql.gz
    DEST_FILE=${DB}_$(date +"%Y-%m-%dT%H:%M:%SZ").sql.gz

    if [ "${S3_FILE_NAME}" != "**None**" ]; then
      DEST_FILE=${S3_FILE_NAME}_${DB}.sql.gz
    fi

    echo "Creating dump of ${DB} database from ${POSTGRES_HOST}..."
    # shellcheck disable=SC2086
    pg_dump $POSTGRES_HOST_OPTS "$DB" | gzip > "$SRC_FILE"

    if [ "${ENCRYPTION_PASSWORD}" != "**None**" ]; then
      SRC_FILE=$(encrypt_file "$SRC_FILE")
      DEST_FILE="${DEST_FILE}.enc"
    fi

    upload_file "$SRC_FILE" "${S3_PATH}${DEST_FILE}"
  done
fi
