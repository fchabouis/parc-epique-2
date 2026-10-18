#!/usr/bin/env bash
# Checks that the latest backup can be restored: loads the database dump into
# a scratch database, compares it with the live one, then drops it. It does
# not touch the live data. Run it after the first backup, then now and then.
set -euo pipefail
cd "$(dirname "$0")"

set -a
. ./.env
. ./backup.env
set +a

SCRATCH=parc_epique_restore_check
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"; docker compose exec -T db dropdb -U "$POSTGRES_USER" --if-exists "$SCRATCH"' EXIT

psql_in() { docker compose exec -T db psql -U "$POSTGRES_USER" -d "$1" -At -c "$2"; }

echo "Restoring the latest database dump..."
restic restore latest --tag db --target "$WORK"
docker compose exec -T db dropdb -U "$POSTGRES_USER" --if-exists "$SCRATCH"
docker compose exec -T db createdb -U "$POSTGRES_USER" "$SCRATCH"
docker compose exec -T db pg_restore -U "$POSTGRES_USER" -d "$SCRATCH" --no-owner --exit-on-error \
  <"$WORK/parc_epique.dump"

for table in playgrounds photos reviews playground_details users; do
  echo "$table: backup $(psql_in "$SCRATCH" "SELECT count(*) FROM $table") / live $(psql_in "$POSTGRES_DB" "SELECT count(*) FROM $table")"
done

echo "Photos in the backup:"
restic ls latest --tag photos | grep -c '/photos/.*[^/]$' || true
echo "Photos on disk: $(find ./uploads/photos -type f 2>/dev/null | wc -l)"
echo "Restore check done."
