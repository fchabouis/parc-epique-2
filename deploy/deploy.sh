#!/usr/bin/env bash
# Updates the site: pulls the new image, migrates the database, restarts.
# Run on the server, in the folder holding docker-compose.yml and .env.
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p uploads
# The application runs as uid 1000 inside the container
[ "$(stat -c %u uploads)" = 1000 ] || chown 1000:1000 uploads

docker compose pull app
docker compose up -d db
docker compose run --rm --no-deps app bin/migrate
docker compose up -d
docker image prune -f >/dev/null
