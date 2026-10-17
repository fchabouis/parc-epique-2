#!/usr/bin/env bash
# Nightly backup of the database and of the photos to a storage outside the
# server, with restic. Run it from cron:
#   0 4 * * * /srv/parc-epique/backup.sh >> /var/log/parc-epique-backup.log 2>&1
set -euo pipefail
cd "$(dirname "$0")"

set -a
. ./.env
. ./backup.env
set +a

# Creates the repository the first time
restic cat config >/dev/null 2>&1 || restic init

# The database, as a pg_dump archive, streamed to restic
docker compose exec -T db pg_dump -U "$POSTGRES_USER" -Fc "$POSTGRES_DB" |
  restic backup --stdin --stdin-filename parc_epique.dump --tag db

# The photos and the export (restic only sends what changed)
restic backup ./uploads --tag photos

restic forget --prune --keep-daily 7 --keep-weekly 4 --keep-monthly 6
restic check --read-data-subset=2%

[ -z "${HEALTHCHECK_PING_URL:-}" ] || curl -fsS -m 10 --retry 3 "$HEALTHCHECK_PING_URL" >/dev/null
echo "Backup done: $(date -Is)"
