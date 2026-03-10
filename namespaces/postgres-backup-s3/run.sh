#! /bin/sh

set -eo pipefail

if [ "${S3_S3V4}" = "yes" ]; then
  aws configure set default.s3.signature_version s3v4
fi

if [ "${SCHEDULE}" = "**None**" ]; then
  sh /backup.sh
else
  # Write crontab for root and run cron in the foreground
  echo "SHELL=/bin/sh" > /etc/cron.d/postgres-backup
  echo "${SCHEDULE} root /bin/sh /backup.sh >> /proc/1/fd/1 2>&1" >> /etc/cron.d/postgres-backup
  chmod 0644 /etc/cron.d/postgres-backup
  crontab /etc/cron.d/postgres-backup
  echo "Scheduled backup with cron: ${SCHEDULE}"
  exec cron -f
fi
